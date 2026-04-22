<?php

declare(strict_types=1);

/**
 * Topic upserter — last-write-wins upsert for Topic records.
 *
 * Purpose:
 *   Applies a single client-side Topic record to the server database using a
 *   last-write-wins (LWW) strategy keyed on updated_at_ms. Enforces ownership
 *   so a user can only modify their own topics.
 *
 * Dependencies:
 *   - App\Models\Topic (Eloquent model, HasUuids)
 *   - App\Models\User (ownership scoping)
 *   - App\Services\Sync\AbstractLwwUpserter (base class; handles transaction,
 *     LWW check, UUID preservation, partial-update semantics)
 *
 * Key concepts:
 *   - LWW rule: incoming row is rejected when existing updated_at_ms >= incoming updated_at_ms.
 *   - Forbidden: a row whose UUID exists but belongs to a different user is rejected.
 *   - Partial updates: color_hint uses preserve() so an absent key does not
 *     overwrite an existing value with null.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Models\Topic;
use App\Models\User;
use App\Services\Sync\AbstractLwwUpserter;
use Illuminate\Database\Eloquent\Model;

/**
 * Upserts a single Topic record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "topics" entity key via
 * AbstractLwwUpserter. Only entity-specific concerns are declared here:
 * model class, ownership check, and field mapping.
 */
final class TopicUpserter extends AbstractLwwUpserter
{
    /**
     * @return class-string<Model>
     */
    protected function modelClass(): string
    {
        return Topic::class;
    }

    /**
     * Reject if a topic with this id exists and belongs to a different user.
     *
     * @param  User  $user  Authenticated user.
     * @param  string  $id  Topic UUID from the client row.
     * @param  array<string, mixed>  $row  Full client row payload.
     * @return string|null 'forbidden' if ownership fails; null to proceed.
     */
    protected function checkOwnership(User $user, string $id, array $row): ?string
    {
        $existing = Topic::find($id);

        return $existing && $existing->user_id !== $user->id ? 'forbidden' : null;
    }

    /**
     * Map client row fields onto the Topic model.
     *
     * color_hint uses preserve() so that a push omitting the key does not
     * overwrite an existing color with null (partial-update semantics).
     *
     * @param  Model  $model  Topic model instance (new or fetched).
     * @param  User  $user  Authenticated owner.
     * @param  array<string, mixed>  $row  Client row payload.
     * @param  Model|null  $existing  Pre-lock existing record, or null on create.
     */
    protected function applyFields(Model $model, User $user, array $row, ?Model $existing): void
    {
        assert($model instanceof Topic);

        $model->user_id = $user->id;
        $model->name = (string) ($row['name'] ?? '');
        $model->color_hint = $this->preserve($row, $existing, 'color_hint');
    }
}
