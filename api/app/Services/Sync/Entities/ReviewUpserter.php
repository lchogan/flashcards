<?php

declare(strict_types=1);

/**
 * Review upserter — insert-only sync handler for Review records.
 *
 * Purpose:
 *   Applies a single client-side Review record to the server database.
 *   Reviews are append-only: there is no LWW update path. A duplicate
 *   client-supplied UUID is rejected with reason "duplicate" rather than
 *   silently overwriting.
 *
 * Dependencies:
 *   - App\Models\Card (ownership resolved via card->deck->user_id)
 *   - App\Models\Review (append-only Eloquent model)
 *   - App\Models\User (authenticated owner)
 *   - App\Jobs\ReplayReviewsForCard (dispatched after insert to recompute FSRS cache)
 *   - App\Services\Sync\RecordUpserter (interface contract)
 *   - App\Services\Sync\UpsertResult (return value object)
 *
 * Key concepts:
 *   - Review is append-only — no LWW update path exists. Once a UUID is stored
 *     the row is immutable. Any push of an existing UUID is a duplicate and
 *     returns accepted=false.
 *   - Ownership: the referenced card must belong to the authenticated user.
 *     Cards have no direct user_id; ownership is enforced via card->deck->user_id.
 *   - UUID preservation: id is not in $fillable, so we set $review->id explicitly
 *     before save() to prevent HasUuids from regenerating the client-supplied UUID.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Jobs\ReplayReviewsForCard;
use App\Models\Card;
use App\Models\Review;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

/**
 * Upserts (insert-only) a single Review record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "reviews" entity key.
 * Ownership is enforced via the parent card's deck user_id — the authenticated
 * user must own the card being reviewed.
 */
final class ReviewUpserter implements RecordUpserter
{
    /**
     * Attempt to insert a Review row.
     *
     * Review is append-only — no LWW update path. Guard order:
     *   1. Missing id or card_id → missing_id
     *   2. Card not found or not owned by user → forbidden
     *   3. Duplicate UUID (row already exists) → duplicate
     *   4. Otherwise insert, dispatch ReplayReviewsForCard, return accepted=true
     *
     * UUID preservation: id is not in $fillable. We assign $review->id directly
     * before save() so HasUuids does not regenerate the client-supplied value.
     *
     * @param  User  $user  Authenticated owner; used to verify card ownership.
     * @param  array<string, mixed>  $row  Raw record payload from the client push request.
     * @return UpsertResult Accepted (true) or rejected (false) with a reason string.
     */
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $cardId = (string) ($row['card_id'] ?? '');

        if ($id === '' || $cardId === '') {
            return new UpsertResult(false, 'missing_id');
        }

        // Ownership: load the card with its deck to check user_id.
        $card = Card::with('deck')->find($cardId);
        if (! $card || $card->deck->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }

        // Review is append-only — no LWW update path. Duplicate UUID → reject.
        if (Review::where('id', $id)->exists()) {
            return new UpsertResult(false, 'duplicate');
        }

        // Insert with client-supplied UUID preserved (id isn't fillable, so we
        // set it explicitly to prevent HasUuids from regenerating it).
        $review = new Review;
        $review->id = $id;
        $review->fill([
            'card_id' => $cardId,
            'user_id' => $user->id,
            'session_id' => $row['session_id'] ?? null,
            'rating' => (int) ($row['rating'] ?? 3),
            'review_duration_ms' => (int) ($row['review_duration_ms'] ?? 0),
            'rated_at_ms' => (int) ($row['rated_at_ms'] ?? 0),
            'state_before' => (array) ($row['state_before'] ?? []),
            'state_after' => (array) ($row['state_after'] ?? []),
            'scheduler_version' => (string) ($row['scheduler_version'] ?? 'fsrs-6'),
            'updated_at_ms' => (int) ($row['updated_at_ms'] ?? 0),
        ]);
        $review->save();

        ReplayReviewsForCard::dispatch($cardId);

        return new UpsertResult(true);
    }
}
