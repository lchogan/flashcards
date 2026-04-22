<?php

declare(strict_types=1);

/**
 * AbstractCursorReader — shared base for cursor-paginated sync pull readers.
 *
 * Purpose:
 *   Extracts the rule-of-four duplication that exists across TopicReader,
 *   DeckReader, SubTopicReader, CardReader, and SessionReader into a single
 *   place. Subclasses declare only what is unique to the entity: the model
 *   class, a user-ownership scope, and a row-projection closure.
 *
 * Dependencies:
 *   - App\Models\User (ownership scoping)
 *   - Illuminate\Database\Eloquent\Builder (query building)
 *   - Illuminate\Database\Eloquent\Model (generic model operations)
 *   - App\Services\Sync\RecordReader (implemented interface)
 *
 * Key concepts:
 *   - Pagination: queries pageSize + 1 rows; the extra row signals hasMore
 *     without a separate COUNT query (one-extra-row trick).
 *   - Cursor: the maximum updated_at_ms in the returned page is passed back
 *     to the caller as the next `since` value.
 *   - Ordered by updated_at_ms ASC for stable cursor-based pagination.
 *
 * Not suitable for:
 *   - CardSubTopicReader — uses nested whereHas traversal rather than a
 *     direct whereIn subquery; the scopeForUser contract does not express that.
 *   - ReviewReader — append-only semantics; structurally similar but
 *     kept separate for clarity and future divergence.
 */

namespace App\Services\Sync;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Template-method base class for cursor-paginated sync pull readers.
 *
 * Subclasses declare:
 *   - modelClass(): the Eloquent model class-string
 *   - scopeForUser(): apply user-ownership constraints to the base query
 *   - projectRow(): map a model instance to the wire-format row array
 *
 * The base class handles:
 *   - updated_at_ms > $since filter
 *   - orderBy updated_at_ms ASC
 *   - pageSize+1 fetch with hasMore detection
 *   - max updated_at_ms cursor computation
 *   - [rows, hasMore, maxUpdatedMs] tuple packaging
 */
abstract class AbstractCursorReader implements RecordReader
{
    /**
     * Return the Eloquent model class-string for this entity.
     *
     * @return class-string<Model>
     */
    abstract protected function modelClass(): string;

    /**
     * Apply user-ownership scoping to the base query.
     *
     * For direct-ownership entities (user_id column on the model), constrain
     * by user_id. For parent-owned entities, use whereIn against the user's
     * deck IDs: $query->whereIn('deck_id', $user->decks()->select('id')).
     *
     * @param  Builder<Model>  $query  The base query for the entity's model.
     * @param  User  $user  Authenticated user whose records are being fetched.
     * @return Builder<Model> The scoped query; must be returned (fluent-style or new instance).
     */
    abstract protected function scopeForUser(Builder $query, User $user): Builder;

    /**
     * Project a single model into the wire-format row array.
     *
     * @param  Model  $model  Hydrated model instance.
     * @return array<string, mixed> Wire-format row to include in the response.
     */
    abstract protected function projectRow(Model $model): array;

    /**
     * Fetch records for the user changed after $since, up to $pageSize rows.
     *
     * Pagination contract: queries $pageSize + 1 rows. If the result set exceeds
     * $pageSize, the extra row signals that more data exists (hasMore=true) and is
     * discarded before projection. The returned maxUpdatedMs is the highest
     * updated_at_ms in the page — the client sends this back as `since` on the
     * next pull to advance the cursor.
     *
     * @param  User  $user  Owner of the records; results are scoped via scopeForUser().
     * @param  int  $since  Millisecond timestamp lower-bound (exclusive).
     * @param  int  $pageSize  Maximum number of rows to include in the returned page.
     * @return array{0: list<array<string, mixed>>, 1: bool, 2: int}
     *                                                               [rows, hasMore, maxUpdatedMs]
     */
    public function read(User $user, int $since, int $pageSize): array
    {
        $modelClass = $this->modelClass();

        $rows = $this->scopeForUser($modelClass::query(), $user)
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)
            ->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (Model $m) => $this->projectRow($m))->values()->all(),
            $hasMore,
            $max,
        ];
    }
}
