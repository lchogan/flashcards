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
 *   - App\Services\Sync\RecordUpserter (interface contract)
 *   - App\Services\Sync\UpsertResult (return value object)
 *
 * Key concepts:
 *   - LWW rule: incoming row is rejected when existing updated_at_ms >= incoming updated_at_ms.
 *   - Forbidden: the referenced deck must exist and be owned by the authenticated user.
 *     Unlike top-level entities (Topic, Deck), there is no user_id column on cards;
 *     ownership is enforced via the deck's user_id.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Models\Card;
use App\Models\Deck;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

/**
 * Upserts a single Card record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "cards" entity key.
 * Ownership is enforced via the parent deck's user_id — the cards table
 * has no direct user_id column.
 */
final class CardUpserter implements RecordUpserter
{
    /**
     * Attempt to upsert a Card row using last-write-wins conflict resolution.
     *
     * LWW rule: if an existing row's updated_at_ms is >= the incoming value,
     * the update is considered stale and rejected with reason "stale". This
     * ensures a slower client cannot overwrite newer server state.
     *
     * Ownership check: the referenced deck_id must belong to the authenticated
     * user. If the deck does not exist or belongs to another user, the row is
     * rejected with reason "forbidden".
     *
     * @param  User  $user  Authenticated owner; used to verify deck ownership.
     * @param  array<string, mixed>  $row  Raw record payload from the client push request.
     * @return UpsertResult Accepted (true) or rejected (false) with a reason string.
     */
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $deckId = (string) ($row['deck_id'] ?? '');
        $incoming = (int) ($row['updated_at_ms'] ?? 0);

        if ($id === '' || $deckId === '') {
            return new UpsertResult(false, 'missing_id');
        }

        $deck = Deck::find($deckId);
        if (! $deck || $deck->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }

        $existing = Card::find($id);
        if ($existing && $existing->updated_at_ms >= $incoming) {
            return new UpsertResult(false, 'stale');
        }

        // Use firstOrNew + explicit id assignment to avoid HasUuids overwriting the
        // client-supplied UUID during mass-assignment (id is not in $fillable, so
        // updateOrCreate's where-clause id would not reach setUniqueIds' empty check).
        $card = Card::firstOrNew(['id' => $id]);
        $card->id = $id;
        $card->fill([
            'deck_id' => $deckId,
            'front_text' => (string) ($row['front_text'] ?? ''),
            'back_text' => (string) ($row['back_text'] ?? ''),
            // TODO(1.15): validate asset ownership and add FK constraint after assets table exists.
            'front_image_asset_id' => $row['front_image_asset_id'] ?? null,
            'back_image_asset_id' => $row['back_image_asset_id'] ?? null,
            'position' => (int) ($row['position'] ?? 0),
            'stability' => isset($row['stability']) ? (float) $row['stability'] : null,
            'difficulty' => isset($row['difficulty']) ? (float) $row['difficulty'] : null,
            'state' => (string) ($row['state'] ?? 'new'),
            'last_reviewed_at_ms' => isset($row['last_reviewed_at_ms']) ? (int) $row['last_reviewed_at_ms'] : null,
            'due_at_ms' => isset($row['due_at_ms']) ? (int) $row['due_at_ms'] : null,
            'lapses' => (int) ($row['lapses'] ?? 0),
            'reps' => (int) ($row['reps'] ?? 0),
            'updated_at_ms' => $incoming,
            'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
        ]);
        $card->save();

        return new UpsertResult(true);
    }
}
