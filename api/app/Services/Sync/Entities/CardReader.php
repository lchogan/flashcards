<?php

declare(strict_types=1);

/**
 * Card reader — paginated fetch of Card records for sync pull.
 *
 * Purpose:
 *   Reads Card rows accessible to the authenticated user that have been
 *   updated after a given millisecond timestamp. Implements the one-extra-row
 *   trick to detect whether a next page exists without a separate COUNT query.
 *
 * Dependencies:
 *   - App\Models\Card (Eloquent model, HasUuids)
 *   - App\Models\User (ownership scoping via decks() relation)
 *   - App\Services\Sync\RecordReader (interface contract)
 *
 * Key concepts:
 *   - Ownership: Card has no direct user_id column. Ownership is enforced
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

use App\Models\Card;
use App\Models\User;
use App\Services\Sync\RecordReader;

/**
 * Reads Card records accessible to the authenticated user updated after a given timestamp.
 *
 * Implements the RecordReader contract for the "cards" entity key.
 * Ownership is enforced via a subquery on the user's owned deck IDs.
 */
final class CardReader implements RecordReader
{
    /**
     * Fetch Card rows for the user changed after $since, up to $pageSize rows.
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
        $rows = Card::query()
            ->whereIn('deck_id', $user->decks()->select('id'))
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)
            ->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (Card $card) => [
                'id' => $card->id,
                'deck_id' => $card->deck_id,
                'front_text' => $card->front_text,
                'back_text' => $card->back_text,
                'front_image_asset_id' => $card->front_image_asset_id,
                'back_image_asset_id' => $card->back_image_asset_id,
                'position' => $card->position,
                'stability' => $card->stability,
                'difficulty' => $card->difficulty,
                'state' => $card->state,
                'last_reviewed_at_ms' => $card->last_reviewed_at_ms,
                'due_at_ms' => $card->due_at_ms,
                'lapses' => $card->lapses,
                'reps' => $card->reps,
                'updated_at_ms' => $card->updated_at_ms,
                'deleted_at_ms' => $card->deleted_at_ms,
            ])->values()->all(),
            $hasMore,
            $max,
        ];
    }
}
