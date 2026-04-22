<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Services\Fsrs\ReviewReplayer;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Replay a card's review history into its FSRS state cache.
 *
 * Enqueued by ReviewUpserter after a successful Review insert. Delegates to
 * ReviewReplayer, which sorts reviews by rated_at_ms and applies the latest
 * state_after to the Card, keeping the cache consistent when reviews arrive
 * out-of-order from multiple devices.
 *
 * Dependencies:
 *   - App\Services\Fsrs\ReviewReplayer (performs the replay logic)
 *   - App\Models\Card (updated with recomputed FSRS state)
 *   - App\Models\Review (source of replay truth)
 *
 * Key concepts:
 *   - The card_id is passed by value (string) rather than as a model instance
 *     to avoid stale model state after serialisation/deserialisation across
 *     queue workers.
 */
final class ReplayReviewsForCard implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * @param  string  $cardId  UUID of the card whose review history should be replayed.
     */
    public function __construct(public readonly string $cardId) {}

    /**
     * Execute the job.
     *
     * Delegates to ReviewReplayer, which applies "last state_after wins"
     * logic over the card's full review log to recompute the Card cache.
     */
    public function handle(): void
    {
        app(ReviewReplayer::class)->replay($this->cardId);
    }
}
