<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\Card;
use App\Models\CardSubTopic;
use App\Models\Deck;
use App\Models\Session;
use App\Models\SubTopic;
use App\Models\Topic;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * PurgeTombstones — removes tombstoned rows older than the retention window.
 *
 * Rationale:
 *   Tombstones (rows with a non-null deleted_at_ms) stay in the sync log so
 *   every client eventually sees the deletion. Once 90 days have elapsed —
 *   long past our maximum acceptable offline window — the tombstone no
 *   longer serves a sync purpose and can be hard-deleted.
 *
 * Schedule:
 *   Runs daily via routes/console.php.
 */
final class PurgeTombstones implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    /** Retention window in days — matches the sync-protocol offline ceiling. */
    private const RETENTION_DAYS = 90;

    /**
     * Delete tombstoned rows across all sync entities whose deleted_at_ms
     * is older than RETENTION_DAYS.
     */
    public function handle(): void
    {
        $cutoff = now()->subDays(self::RETENTION_DAYS)->getTimestampMs();

        $models = [
            Topic::class,
            Deck::class,
            SubTopic::class,
            Card::class,
            CardSubTopic::class,
            Session::class,
        ];

        foreach ($models as $model) {
            $model::query()
                ->whereNotNull('deleted_at_ms')
                ->where('deleted_at_ms', '<', $cutoff)
                ->delete();
        }
    }
}
