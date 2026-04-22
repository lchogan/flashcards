<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;

/**
 * Hard-deletes users whose 30-day grace period has elapsed.
 *
 * Scheduled daily at 03:00 via Schedule::job() in routes/console.php.
 * Cascades through all owned rows (decks, cards, reviews, …) via the FK
 * onDelete cascades set in their migrations.
 *
 * Future: when R2 images land (v1.5), purge the user's image assets from
 * storage *before* the DB row so orphaned blobs don't accumulate.
 */
final class HardDeleteExpiredUsers implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public function handle(): void
    {
        User::whereNotNull('scheduled_delete_at')
            ->where('scheduled_delete_at', '<', now())
            ->each(function (User $user) {
                DB::transaction(function () use ($user) {
                    // TODO(1.5): purge R2 assets owned by this user before the row drop.
                    $user->tokens()->delete();
                    $user->delete();
                });
            });
    }
}
