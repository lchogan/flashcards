<?php

declare(strict_types=1);

/**
 * SubTopic upserter — last-write-wins upsert for SubTopic records.
 *
 * Purpose:
 *   Applies a single client-side SubTopic record to the server database using a
 *   last-write-wins (LWW) strategy keyed on updated_at_ms. Enforces ownership
 *   indirectly: ownership is determined by the parent Deck's user_id rather than
 *   a direct user_id column on the sub_topics table.
 *
 * Dependencies:
 *   - App\Models\Deck (parent entity; ownership resolved via deck->user_id)
 *   - App\Models\SubTopic (Eloquent model, HasUuids)
 *   - App\Models\User (ownership scoping)
 *   - App\Services\Sync\AbstractLwwUpserter (base class; handles transaction,
 *     LWW check, UUID preservation, partial-update semantics)
 *
 * Key concepts:
 *   - LWW rule: incoming row is rejected when existing updated_at_ms >= incoming updated_at_ms.
 *   - Forbidden: the referenced deck must exist and be owned by the authenticated user.
 *     Unlike top-level entities (Topic, Deck), there is no user_id column on sub_topics;
 *     ownership is enforced via the deck's user_id.
 *   - Partial updates: color_hint uses preserve() so absent keys do not overwrite
 *     existing values with null.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\SubTopic;
use App\Models\User;
use App\Services\Sync\AbstractLwwUpserter;
use Illuminate\Database\Eloquent\Model;

/**
 * Upserts a single SubTopic record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "sub_topics" entity key via
 * AbstractLwwUpserter. Ownership is enforced via the parent deck's user_id —
 * the sub_topics table has no direct user_id column.
 */
final class SubTopicUpserter extends AbstractLwwUpserter
{
    /**
     * @return class-string<Model>
     */
    protected function modelClass(): string
    {
        return SubTopic::class;
    }

    /**
     * Reject if deck_id is missing or the referenced deck is not owned by the user.
     *
     * Also returns 'missing_id' when deck_id is absent, since a SubTopic without
     * a parent deck is structurally invalid.
     *
     * @param  User  $user  Authenticated user.
     * @param  string  $id  SubTopic UUID from the client row.
     * @param  array<string, mixed>  $row  Full client row payload (must contain deck_id).
     * @return string|null 'missing_id', 'forbidden', or null to proceed.
     */
    protected function checkOwnership(User $user, string $id, array $row): ?string
    {
        $deckId = (string) ($row['deck_id'] ?? '');
        if ($deckId === '') {
            return 'missing_id';
        }

        $deck = Deck::find($deckId);

        return (! $deck || $deck->user_id !== $user->id) ? 'forbidden' : null;
    }

    /**
     * Map client row fields onto the SubTopic model.
     *
     * color_hint uses preserve() so that a push omitting the key does not
     * overwrite an existing value with null (partial-update semantics).
     *
     * @param  Model  $model  SubTopic model instance (new or fetched).
     * @param  User  $user  Authenticated owner (unused here; ownership is via deck).
     * @param  array<string, mixed>  $row  Client row payload.
     * @param  Model|null  $existing  Pre-lock existing record, or null on create.
     */
    protected function applyFields(Model $model, User $user, array $row, ?Model $existing): void
    {
        assert($model instanceof SubTopic);

        $model->deck_id = (string) ($row['deck_id'] ?? '');
        $model->name = (string) ($row['name'] ?? '');
        $model->position = (int) ($row['position'] ?? 0);
        $model->color_hint = $this->preserve($row, $existing, 'color_hint');
    }
}
