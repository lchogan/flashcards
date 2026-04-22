<?php

declare(strict_types=1);

namespace App\Services\Fsrs;

use App\Models\Card;
use App\Models\Review;

/**
 * Review replayer — recomputes a Card's FSRS state cache from its review log.
 *
 * Purpose:
 *   When reviews arrive out-of-order from multiple devices, the Card's cached
 *   FSRS fields (stability, difficulty, state, lapses, reps, last_reviewed_at_ms,
 *   due_at_ms) can drift from the authoritative review log. This service picks
 *   the latest review by rated_at_ms and copies its state_after into the Card,
 *   and recounts total reps and lapses.
 *
 * Dependencies:
 *   - App\Models\Card
 *   - App\Models\Review
 *
 * Key concepts:
 *   "Last state_after wins" — the iOS client has already computed the post-review
 *   FSRS state for each review. The server does not re-run the FSRS scheduler;
 *   it trusts the review log as source of truth and promotes the most recent
 *   entry's state_after to the Card cache. reps and lapses are aggregated from
 *   the full log, not taken from any single review.
 */
final class ReviewReplayer
{
    /**
     * Replay all reviews for the given card and update the Card cache.
     *
     * No-op if the card doesn't exist or has no reviews yet. Counts total
     * reps from all reviews, and lapses from reviews with rating = 1 (Again).
     *
     * @param  string  $cardId  UUID of the Card to recompute.
     */
    public function replay(string $cardId): void
    {
        $card = Card::find($cardId);
        if (! $card) {
            return;
        }

        // "Last state_after wins": find the most recent review by rated_at_ms.
        // The iOS client computed and stored the post-review FSRS state; we
        // simply promote it to the Card cache rather than re-running the
        // scheduler server-side.
        $latest = Review::where('card_id', $cardId)
            ->orderByDesc('rated_at_ms')
            ->first();

        if (! $latest) {
            return;
        }

        $after = $latest->state_after;

        $card->update([
            'stability' => $after['stability'] ?? null,
            'difficulty' => $after['difficulty'] ?? null,
            'state' => $after['state'] ?? 'new',
            'last_reviewed_at_ms' => $latest->rated_at_ms,
            'due_at_ms' => $after['due_at_ms'] ?? null,
            // Aggregate reps and lapses from the full review log, not just the
            // latest entry, so out-of-order arrivals don't under-count.
            'reps' => Review::where('card_id', $cardId)->count(),
            'lapses' => Review::where('card_id', $cardId)->where('rating', 1)->count(),
            'updated_at_ms' => (int) (microtime(true) * 1000),
        ]);
    }
}
