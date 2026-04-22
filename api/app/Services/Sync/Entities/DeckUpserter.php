<?php

declare(strict_types=1);

/**
 * Deck upserter — last-write-wins upsert for Deck records.
 *
 * Purpose:
 *   Applies a single client-side Deck record to the server database using a
 *   last-write-wins (LWW) strategy keyed on updated_at_ms. Enforces ownership
 *   so a user can only modify their own decks.
 *
 * Dependencies:
 *   - App\Models\Deck (Eloquent model, HasUuids)
 *   - App\Models\User (ownership scoping)
 *   - App\Services\Sync\AbstractLwwUpserter (base class; handles transaction,
 *     LWW check, UUID preservation, partial-update semantics)
 *
 * Key concepts:
 *   - LWW rule: incoming row is rejected when existing updated_at_ms >= incoming updated_at_ms.
 *   - Forbidden: a row whose UUID exists but belongs to a different user is rejected.
 *   - Partial updates: topic_id, description, and last_studied_at_ms use preserve()
 *     so absent keys do not overwrite existing values with null.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\User;
use App\Services\Sync\AbstractLwwUpserter;
use Illuminate\Database\Eloquent\Model;

/**
 * Upserts a single Deck record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "decks" entity key via
 * AbstractLwwUpserter. Only entity-specific concerns are declared here:
 * model class, ownership check, and field mapping.
 */
final class DeckUpserter extends AbstractLwwUpserter
{
    /**
     * @return class-string<Model>
     */
    protected function modelClass(): string
    {
        return Deck::class;
    }

    /**
     * Reject if a deck with this id exists and belongs to a different user.
     *
     * @param  User  $user  Authenticated user.
     * @param  string  $id  Deck UUID from the client row.
     * @param  array<string, mixed>  $row  Full client row payload.
     * @return string|null 'forbidden' if ownership fails; null to proceed.
     */
    protected function checkOwnership(User $user, string $id, array $row): ?string
    {
        $existing = Deck::find($id);

        return $existing && $existing->user_id !== $user->id ? 'forbidden' : null;
    }

    /**
     * Map client row fields onto the Deck model.
     *
     * topic_id, description, and last_studied_at_ms use preserve() so that
     * a push omitting those keys does not overwrite existing values with null
     * (partial-update semantics).
     *
     * @param  Model  $model  Deck model instance (new or fetched).
     * @param  User  $user  Authenticated owner.
     * @param  array<string, mixed>  $row  Client row payload.
     * @param  Model|null  $existing  Pre-lock existing record, or null on create.
     */
    protected function applyFields(Model $model, User $user, array $row, ?Model $existing): void
    {
        assert($model instanceof Deck);

        $model->user_id = $user->id;
        $model->topic_id = $this->preserve($row, $existing, 'topic_id');
        $model->title = (string) ($row['title'] ?? '');
        $model->description = $this->preserve($row, $existing, 'description');
        $model->accent_color = (string) ($row['accent_color'] ?? 'amber');
        $model->default_study_mode = (string) ($row['default_study_mode'] ?? 'smart');
        $model->card_count = (int) ($row['card_count'] ?? 0);
        $model->last_studied_at_ms = $this->preserve($row, $existing, 'last_studied_at_ms', castInt: true);
    }
}
