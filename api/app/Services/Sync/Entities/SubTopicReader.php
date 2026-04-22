<?php

declare(strict_types=1);

/**
 * SubTopic reader — paginated fetch of SubTopic records for sync pull.
 *
 * Purpose:
 *   Reads SubTopic rows accessible to the authenticated user that have been
 *   updated after a given millisecond timestamp. Implements the one-extra-row
 *   trick to detect whether a next page exists without a separate COUNT query.
 *
 * Dependencies:
 *   - App\Models\SubTopic (Eloquent model, HasUuids)
 *   - App\Models\User (ownership scoping via decks() relation)
 *   - App\Services\Sync\RecordReader (interface contract)
 *
 * Key concepts:
 *   - Ownership: SubTopic has no direct user_id column. Ownership is enforced
 *     by constraining deck_id to the set of deck IDs owned by the user, resolved
 *     via a subquery on $user->decks()->select('id'). This is why the User model
 *     must expose a decks() HasMany relation.
 *   - Pagination: queries pageSize + 1 rows; if the result exceeds pageSize,
 *     hasMore=true is returned and the extra row is discarded before mapping.
 *   - nextSince: the maximum updated_at_ms in the returned page is passed back
 *     to the client as the cursor for the next pull request.
 *   - Ordered by updated_at_ms ASC so cursored pagination is stable.
 */

namespace App\Services\Sync\Entities;

use App\Models\SubTopic;
use App\Models\User;
use App\Services\Sync\RecordReader;

/**
 * Reads SubTopic records accessible to the authenticated user updated after a given timestamp.
 *
 * Implements the RecordReader contract for the "sub_topics" entity key.
 * Ownership is enforced via a subquery on the user's owned deck IDs.
 */
final class SubTopicReader implements RecordReader
{
    /**
     * Fetch SubTopic rows for the user changed after $since, up to $pageSize rows.
     *
     * Pagination contract: queries $pageSize + 1 rows. If the result set exceeds
     * $pageSize, the extra row signals that more data exists (hasMore=true) and is
     * discarded before serialisation. The returned maxUpdatedMs is the highest
     * updated_at_ms in the page — the client sends this back as `since` on the
     * next pull to advance the cursor.
     *
     * Ownership is enforced by restricting deck_id to the subquery
     * $user->decks()->select('id'), which returns only decks owned by the user.
     *
     * @param  User  $user  Owner of the records; results are scoped to this user's decks.
     * @param  int  $since  Millisecond timestamp lower-bound (exclusive); only rows updated after this are returned.
     * @param  int  $pageSize  Maximum number of rows to include in the returned page.
     * @return array{0: list<array<string, mixed>>, 1: bool, 2: int}
     *                                                               [rows, hasMore, maxUpdatedMs]
     */
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = SubTopic::query()
            ->whereIn('deck_id', $user->decks()->select('id'))
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)
            ->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (SubTopic $st) => [
                'id' => $st->id,
                'deck_id' => $st->deck_id,
                'name' => $st->name,
                'position' => $st->position,
                'color_hint' => $st->color_hint,
                'updated_at_ms' => $st->updated_at_ms,
                'deleted_at_ms' => $st->deleted_at_ms,
            ])->values()->all(),
            $hasMore,
            $max,
        ];
    }
}
