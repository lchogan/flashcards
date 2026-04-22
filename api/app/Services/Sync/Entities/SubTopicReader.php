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
 *   - App\Services\Sync\AbstractCursorReader (base class; handles pagination,
 *     cursor computation, and the [rows, hasMore, maxUpdatedMs] tuple)
 *
 * Key concepts:
 *   - Ownership: SubTopic has no direct user_id column. Ownership is enforced
 *     by constraining deck_id to the set of deck IDs owned by the user, resolved
 *     via a subquery on $user->decks()->select('id'). This is why the User model
 *     must expose a decks() HasMany relation.
 *   - Pagination: one-extra-row trick; see AbstractCursorReader.
 *   - nextSince: max updated_at_ms in page → client's next `since`.
 *   - Ordered by updated_at_ms ASC so cursored pagination is stable.
 */

namespace App\Services\Sync\Entities;

use App\Models\SubTopic;
use App\Models\User;
use App\Services\Sync\AbstractCursorReader;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Reads SubTopic records accessible to the authenticated user updated after a given timestamp.
 *
 * Implements the RecordReader contract for the "sub_topics" entity key via
 * AbstractCursorReader. Ownership is enforced via a whereIn subquery on the
 * user's owned deck IDs.
 */
final class SubTopicReader extends AbstractCursorReader
{
    /**
     * @return class-string<Model>
     */
    protected function modelClass(): string
    {
        return SubTopic::class;
    }

    /**
     * Scope the query to sub-topics belonging to decks owned by the user.
     *
     * Uses a whereIn subquery on $user->decks()->select('id') so that ownership
     * is enforced without a JOIN — the User model must expose a decks() HasMany.
     *
     * @param  Builder<Model>  $query  Base query for the SubTopic model.
     * @param  User  $user  Authenticated user.
     * @return Builder<Model> Scoped query.
     */
    protected function scopeForUser(Builder $query, User $user): Builder
    {
        return $query->whereIn('deck_id', $user->decks()->select('id'));
    }

    /**
     * Project a SubTopic model into the wire-format row.
     *
     * @param  Model  $model  Hydrated SubTopic instance.
     * @return array<string, mixed> Wire-format row.
     */
    protected function projectRow(Model $model): array
    {
        assert($model instanceof SubTopic);

        return [
            'id' => $model->id,
            'deck_id' => $model->deck_id,
            'name' => $model->name,
            'position' => $model->position,
            'color_hint' => $model->color_hint,
            'updated_at_ms' => $model->updated_at_ms,
            'deleted_at_ms' => $model->deleted_at_ms,
        ];
    }
}
