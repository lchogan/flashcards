<?php

declare(strict_types=1);

/**
 * Deck reader — paginated fetch of Deck records for sync pull.
 *
 * Purpose:
 *   Reads Deck rows owned by the authenticated user that have been updated
 *   after a given millisecond timestamp. Implements the one-extra-row trick
 *   to detect whether a next page exists without a separate COUNT query.
 *
 * Dependencies:
 *   - App\Models\Deck (Eloquent model, HasUuids)
 *   - App\Models\User (ownership scoping)
 *   - App\Services\Sync\RecordReader (interface contract)
 *
 * Key concepts:
 *   - Pagination: queries pageSize + 1 rows; if the result exceeds pageSize,
 *     hasMore=true is returned and the extra row is discarded before mapping.
 *   - nextSince: the maximum updated_at_ms in the returned page is passed back
 *     to the client as the cursor for the next pull request.
 *   - Ordered by updated_at_ms ASC so cursored pagination is stable.
 */

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\User;
use App\Services\Sync\RecordReader;

/**
 * Reads Deck records for the authenticated user updated after a given timestamp.
 *
 * Implements the RecordReader contract for the "decks" entity key.
 */
final class DeckReader implements RecordReader
{
    /**
     * Fetch Deck rows for the user changed after $since, up to $pageSize rows.
     *
     * Pagination contract: queries $pageSize + 1 rows. If the result set exceeds
     * $pageSize, the extra row signals that more data exists (hasMore=true) and is
     * discarded before serialisation. The returned maxUpdatedMs is the highest
     * updated_at_ms in the page — the client sends this back as `since` on the
     * next pull to advance the cursor.
     *
     * @param  User  $user  Owner of the records; results are scoped to this user.
     * @param  int  $since  Millisecond timestamp lower-bound (exclusive); only rows updated after this are returned.
     * @param  int  $pageSize  Maximum number of rows to include in the returned page.
     * @return array{0: list<array<string, mixed>>, 1: bool, 2: int}
     *                                                               [rows, hasMore, maxUpdatedMs]
     */
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = Deck::query()
            ->where('user_id', $user->id)
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)
            ->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (Deck $d) => [
                'id' => $d->id,
                'topic_id' => $d->topic_id,
                'title' => $d->title,
                'description' => $d->description,
                'accent_color' => $d->accent_color,
                'default_study_mode' => $d->default_study_mode,
                'card_count' => $d->card_count,
                'last_studied_at_ms' => $d->last_studied_at_ms,
                'updated_at_ms' => $d->updated_at_ms,
                'deleted_at_ms' => $d->deleted_at_ms,
            ])->values()->all(),
            $hasMore,
            $max,
        ];
    }
}
