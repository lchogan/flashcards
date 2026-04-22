<?php

declare(strict_types=1);

/**
 * Card upserter — last-write-wins upsert for Card records.
 *
 * Purpose:
 *   Applies a single client-side Card record to the server database using a
 *   last-write-wins (LWW) strategy keyed on updated_at_ms. Enforces ownership
 *   indirectly: ownership is determined by the parent Deck's user_id rather than
 *   a direct user_id column on the cards table.
 *
 * Dependencies:
 *   - App\Models\Card (Eloquent model, HasUuids)
 *   - App\Models\Deck (parent entity; ownership resolved via deck->user_id)
 *   - App\Models\User (ownership scoping)
 *   - App\Services\Sync\AbstractLwwUpserter (base class; handles transaction,
 *     LWW check, UUID preservation, partial-update semantics)
 *
 * Key concepts:
 *   - LWW rule: incoming row is rejected when existing updated_at_ms >= incoming updated_at_ms.
 *   - Forbidden: the referenced deck must exist and be owned by the authenticated user.
 *     Unlike top-level entities (Topic, Deck), there is no user_id column on cards;
 *     ownership is enforced via the deck's user_id.
 *   - Partial updates: front_image_asset_id, back_image_asset_id, stability,
 *     difficulty, last_reviewed_at_ms, and due_at_ms use preserve() so absent keys
 *     do not overwrite existing values with null.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Models\Card;
use App\Models\Deck;
use App\Models\User;
use App\Services\Sync\AbstractLwwUpserter;
use Illuminate\Database\Eloquent\Model;

/**
 * Upserts a single Card record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "cards" entity key via
 * AbstractLwwUpserter. Ownership is enforced via the parent deck's user_id —
 * the cards table has no direct user_id column.
 */
final class CardUpserter extends AbstractLwwUpserter
{
    /**
     * @return class-string<Model>
     */
    protected function modelClass(): string
    {
        return Card::class;
    }

    /**
     * Reject if deck_id is missing or the referenced deck is not owned by the user.
     *
     * Also returns 'missing_id' when deck_id is absent, since a Card without
     * a parent deck is structurally invalid.
     *
     * @param  User  $user  Authenticated user.
     * @param  string  $id  Card UUID from the client row.
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
     * Map client row fields onto the Card model.
     *
     * front_image_asset_id, back_image_asset_id, stability, difficulty,
     * last_reviewed_at_ms, and due_at_ms use preserve() so that absent keys
     * do not overwrite existing values with null (partial-update semantics).
     *
     * TODO(1.15): validate asset ownership and add FK constraint after assets table exists.
     *
     * @param  Model  $model  Card model instance (new or fetched).
     * @param  User  $user  Authenticated owner (unused here; ownership is via deck).
     * @param  array<string, mixed>  $row  Client row payload.
     * @param  Model|null  $existing  Pre-lock existing record, or null on create.
     */
    protected function applyFields(Model $model, User $user, array $row, ?Model $existing): void
    {
        assert($model instanceof Card);

        $model->deck_id = (string) ($row['deck_id'] ?? '');
        $model->front_text = (string) ($row['front_text'] ?? '');
        $model->back_text = (string) ($row['back_text'] ?? '');
        $model->front_image_asset_id = $this->preserve($row, $existing, 'front_image_asset_id');
        $model->back_image_asset_id = $this->preserve($row, $existing, 'back_image_asset_id');
        $model->position = (int) ($row['position'] ?? 0);
        $stability = $this->preserve($row, $existing, 'stability');
        $model->stability = $stability !== null ? (float) $stability : null;

        $difficulty = $this->preserve($row, $existing, 'difficulty');
        $model->difficulty = $difficulty !== null ? (float) $difficulty : null;
        $model->state = (string) ($row['state'] ?? 'new');
        $model->last_reviewed_at_ms = $this->preserve($row, $existing, 'last_reviewed_at_ms', castInt: true);
        $model->due_at_ms = $this->preserve($row, $existing, 'due_at_ms', castInt: true);
        $model->lapses = (int) ($row['lapses'] ?? 0);
        $model->reps = (int) ($row['reps'] ?? 0);
    }
}
