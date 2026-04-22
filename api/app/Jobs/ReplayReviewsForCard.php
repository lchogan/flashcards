<?php

declare(strict_types=1);

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Replay a card's review history into its FSRS state cache.
 *
 * Enqueued by ReviewUpserter after a successful Review insert. The handle()
 * body is wired in Task 1.13 — in Task 1.12 this is a stub so the upserter
 * dispatch call resolves without a class-not-found error.
 *
 * Dependencies:
 *   - App\Models\Card (updated with recomputed FSRS state in Task 1.13)
 *   - App\Models\Review (source of replay truth in Task 1.13)
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
     * Wired in Task 1.13 — currently a no-op stub.
     */
    public function handle(): void
    {
        // Wired in Task 1.13.
    }
}
