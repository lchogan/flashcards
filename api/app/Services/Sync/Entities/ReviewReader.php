<?php

declare(strict_types=1);

/**
 * Review reader — paginated fetch of Review records for sync pull.
 *
 * Purpose:
 *   Reads Review rows owned by the authenticated user that have been
 *   updated after a given millisecond timestamp. Implements the one-extra-row
 *   trick to detect whether a next page exists without a separate COUNT query.
 *
 * Dependencies:
 *   - App\Models\Review (Eloquent model, HasUuids, append-only)
 *   - App\Models\User (ownership scoping via user_id column)
 *   - App\Services\Sync\RecordReader (interface contract)
 *
 * Key concepts:
 *   - Ownership: Review has a direct user_id column so ownership is enforced
 *     with a simple where('user_id', $user->id) — no subquery needed (unlike
 *     Card/SubTopic which derive ownership through parent relations).
 *   - Pagination: queries pageSize + 1 rows; if the result exceeds pageSize,
 *     hasMore=true is returned and the extra row is discarded before mapping.
 *   - nextSince: the maximum updated_at_ms in the returned page is passed back
 *     to the client as the cursor for the next pull request.
 *   - Ordered by updated_at_ms ASC so cursored pagination is stable.
 *
 * Does NOT extend AbstractCursorReader:
 *   Review is append-only and carries significantly more fields than any other
 *   entity (state_before, state_after as JSON, scheduler_version, etc.). While
 *   structurally compatible with the base class, keeping it standalone preserves
 *   the semantic distinction between mutable LWW entities and immutable review
 *   events, and avoids conflating the two reader categories for future maintainers.
 */

namespace App\Services\Sync\Entities;

use App\Models\Review;
use App\Models\User;
use App\Services\Sync\RecordReader;

/**
 * Reads Review records owned by the authenticated user updated after a given timestamp.
 *
 * Implements the RecordReader contract for the "reviews" entity key.
 * Ownership is enforced directly via the user_id column on reviews.
 */
final class ReviewReader implements RecordReader
{
    /**
     * Fetch Review rows for the user changed after $since, up to $pageSize rows.
     *
     * Pagination contract: queries $pageSize + 1 rows. If the result set exceeds
     * $pageSize, the extra row signals that more data exists (hasMore=true) and is
     * discarded before serialisation. The returned maxUpdatedMs is the highest
     * updated_at_ms in the page — the client sends this back as `since` on the
     * next pull to advance the cursor.
     *
     * Row shape: 11 fields — id, card_id, user_id, session_id, rating,
     * review_duration_ms, rated_at_ms, state_before, state_after,
     * scheduler_version, updated_at_ms.
     *
     * @param  User  $user  Owner of the records; results are scoped to this user's reviews.
     * @param  int  $since  Millisecond timestamp lower-bound (exclusive); only rows updated after this are returned.
     * @param  int  $pageSize  Maximum number of rows to include in the returned page.
     * @return array{0: list<array<string, mixed>>, 1: bool, 2: int}
     *                                                               [rows, hasMore, maxUpdatedMs]
     */
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = Review::query()
            ->where('user_id', $user->id)
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)
            ->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (Review $review) => [
                'id' => $review->id,
                'card_id' => $review->card_id,
                'user_id' => $review->user_id,
                'session_id' => $review->session_id,
                'rating' => $review->rating,
                'review_duration_ms' => $review->review_duration_ms,
                'rated_at_ms' => $review->rated_at_ms,
                'state_before' => $review->state_before,
                'state_after' => $review->state_after,
                'scheduler_version' => $review->scheduler_version,
                'updated_at_ms' => $review->updated_at_ms,
            ])->values()->all(),
            $hasMore,
            $max,
        ];
    }
}
