<?php

declare(strict_types=1);

/**
 * Session upserter — last-write-wins upsert for Session (study_sessions) records.
 *
 * Purpose:
 *   Applies a single client-side Session record to the server database using a
 *   last-write-wins (LWW) strategy keyed on updated_at_ms. Enforces that the
 *   referenced deck belongs to the authenticated user so sessions cannot be
 *   attached to decks the user does not own.
 *
 * Dependencies:
 *   - App\Models\Deck (ownership check via deck->user_id)
 *   - App\Models\Session (Eloquent model, HasUuids, table=study_sessions)
 *   - App\Models\User (authenticated owner)
 *   - App\Services\Sync\AbstractLwwUpserter (base class; handles transaction,
 *     LWW check, UUID preservation, partial-update semantics)
 *
 * Key concepts:
 *   - LWW rule: incoming row is rejected when existing updated_at_ms >= incoming updated_at_ms.
 *   - Ownership: the referenced deck must exist and its user_id must match the
 *     authenticated user. Missing or foreign decks yield a "forbidden" result.
 *   - Partial updates: ended_at_ms uses preserve() so an absent key does not
 *     overwrite an existing value with null.
 *   - UUID preservation: id is not in $fillable; the base class sets $model->id
 *     explicitly before save() so HasUuids does not regenerate it.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\Session;
use App\Models\User;
use App\Services\Sync\AbstractLwwUpserter;
use Illuminate\Database\Eloquent\Model;

/**
 * Upserts a single Session record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "sessions" entity key via
 * AbstractLwwUpserter. Ownership is enforced by verifying the referenced
 * deck belongs to the authenticated user.
 */
final class SessionUpserter extends AbstractLwwUpserter
{
    /**
     * @return class-string<Model>
     */
    protected function modelClass(): string
    {
        return Session::class;
    }

    /**
     * Reject if deck_id is missing or the referenced deck is not owned by the user.
     *
     * Also returns 'missing_id' when deck_id is absent, since a Session without
     * a parent deck is structurally invalid.
     *
     * @param  User  $user  Authenticated user.
     * @param  string  $id  Session UUID from the client row.
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
     * Map client row fields onto the Session model.
     *
     * ended_at_ms uses preserve() so that a push omitting the key does not
     * overwrite an existing value with null (partial-update semantics).
     *
     * @param  Model  $model  Session model instance (new or fetched).
     * @param  User  $user  Authenticated owner; set as user_id on the session.
     * @param  array<string, mixed>  $row  Client row payload.
     * @param  Model|null  $existing  Pre-lock existing record, or null on create.
     */
    protected function applyFields(Model $model, User $user, array $row, ?Model $existing): void
    {
        assert($model instanceof Session);

        $model->user_id = $user->id;
        $model->deck_id = (string) ($row['deck_id'] ?? '');
        $model->mode = (string) ($row['mode'] ?? 'smart');
        $model->started_at_ms = (int) ($row['started_at_ms'] ?? 0);
        $model->ended_at_ms = $this->preserve($row, $existing, 'ended_at_ms', castInt: true);
        $model->cards_reviewed = (int) ($row['cards_reviewed'] ?? 0);
        $model->accuracy_pct = (float) ($row['accuracy_pct'] ?? 0);
        $model->mastery_delta = (float) ($row['mastery_delta'] ?? 0);
    }
}
