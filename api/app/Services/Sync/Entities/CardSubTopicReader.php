<?php

declare(strict_types=1);

/**
 * CardSubTopic reader — paginated fetch of CardSubTopic records for sync pull.
 *
 * Purpose:
 *   Reads CardSubTopic rows accessible to the authenticated user that have been
 *   updated after a given millisecond timestamp. Implements the one-extra-row
 *   trick to detect whether a next page exists without a separate COUNT query.
 *
 * Dependencies:
 *   - App\Models\CardSubTopic (Eloquent model, HasUuids)
 *   - App\Models\User (ownership scoping via nested relations)
 *   - App\Services\Sync\RecordReader (interface contract)
 *
 * Key concepts:
 *   - Ownership: CardSubTopic has no direct user_id column. Ownership is enforced
 *     by traversing two levels of relations: association → card → deck → user.
 *     The whereHas('card', fn => whereHas('deck', fn => where('user_id', ...))) chain
 *     emits a correlated EXISTS subquery — safe and efficient because both card_id and
 *     user_id are indexed. No JOIN is required; Eloquent resolves each level correctly.
 *   - Pagination: queries pageSize + 1 rows; if the result exceeds pageSize,
 *     hasMore=true is returned and the extra row is discarded before mapping.
 *   - nextSince: the maximum updated_at_ms in the returned page is passed back
 *     to the client as the cursor for the next pull request.
 *   - Ordered by updated_at_ms ASC so cursored pagination is stable.
 */

namespace App\Services\Sync\Entities;

use App\Models\CardSubTopic;
use App\Models\User;
use App\Services\Sync\RecordReader;

/**
 * Reads CardSubTopic records accessible to the authenticated user updated after a given timestamp.
 *
 * Implements the RecordReader contract for the "card_sub_topics" entity key.
 * Ownership is enforced via a two-level whereHas traversal: association → card → deck → user.
 */
final class CardSubTopicReader implements RecordReader
{
    /**
     * Fetch CardSubTopic rows for the user changed after $since, up to $pageSize rows.
     *
     * Pagination contract: queries $pageSize + 1 rows. If the result set exceeds
     * $pageSize, the extra row signals that more data exists (hasMore=true) and is
     * discarded before serialisation. The returned maxUpdatedMs is the highest
     * updated_at_ms in the page — the client sends this back as `since` on the
     * next pull to advance the cursor.
     *
     * Ownership is enforced by the nested whereHas chain:
     *   whereHas('card', fn ($q) => $q->whereHas('deck', fn ($q2) => $q2->where('user_id', $user->id)))
     * This traverses card_sub_topics → cards → decks and filters by the deck's
     * user_id, ensuring that only associations whose card belongs to a deck owned
     * by the authenticated user are returned.
     *
     * @param  User  $user  Owner of the records; results are scoped to this user via card → deck ownership.
     * @param  int  $since  Millisecond timestamp lower-bound (exclusive); only rows updated after this are returned.
     * @param  int  $pageSize  Maximum number of rows to include in the returned page.
     * @return array{0: list<array<string, mixed>>, 1: bool, 2: int}
     *                                                               [rows, hasMore, maxUpdatedMs]
     */
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = CardSubTopic::query()
            ->whereHas('card', fn ($q) => $q->whereHas('deck', fn ($q2) => $q2->where('user_id', $user->id)))
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)
            ->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (CardSubTopic $assoc) => [
                'id' => $assoc->id,
                'card_id' => $assoc->card_id,
                'sub_topic_id' => $assoc->sub_topic_id,
                'updated_at_ms' => $assoc->updated_at_ms,
                'deleted_at_ms' => $assoc->deleted_at_ms,
            ])->values()->all(),
            $hasMore,
            $max,
        ];
    }
}
