<?php

declare(strict_types=1);

/**
 * Session reader — paginated fetch of Session (study_sessions) records for sync pull.
 *
 * Purpose:
 *   Reads Session rows owned by the authenticated user that have been updated
 *   after a given millisecond timestamp. Implements the one-extra-row trick to
 *   detect whether a next page exists without a separate COUNT query.
 *
 * Dependencies:
 *   - App\Models\Session (Eloquent model, HasUuids, table=study_sessions)
 *   - App\Models\User (ownership scoping)
 *   - App\Services\Sync\AbstractCursorReader (base class; handles pagination,
 *     cursor computation, and the [rows, hasMore, maxUpdatedMs] tuple)
 *
 * Key concepts:
 *   - Ownership: scoped by user_id directly on the study_sessions table.
 *   - Pagination: one-extra-row trick; see AbstractCursorReader.
 *   - nextSince: max updated_at_ms in page → client's next `since`.
 *   - Ordered by updated_at_ms ASC so cursored pagination is stable.
 */

namespace App\Services\Sync\Entities;

use App\Models\Session;
use App\Models\User;
use App\Services\Sync\AbstractCursorReader;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Reads Session records for the authenticated user updated after a given timestamp.
 *
 * Implements the RecordReader contract for the "sessions" entity key via
 * AbstractCursorReader. Only entity-specific concerns are declared here:
 * model class, ownership scope, and row projection.
 */
final class SessionReader extends AbstractCursorReader
{
    /**
     * @return class-string<Model>
     */
    protected function modelClass(): string
    {
        return Session::class;
    }

    /**
     * Scope the query to sessions owned by the authenticated user.
     *
     * @param  Builder<Model>  $query  Base query for the Session model.
     * @param  User  $user  Authenticated user.
     * @return Builder<Model> Scoped query.
     */
    protected function scopeForUser(Builder $query, User $user): Builder
    {
        return $query->where('user_id', $user->id);
    }

    /**
     * Project a Session model into the wire-format row.
     *
     * @param  Model  $model  Hydrated Session instance.
     * @return array<string, mixed> Wire-format row.
     */
    protected function projectRow(Model $model): array
    {
        assert($model instanceof Session);

        return [
            'id' => $model->id,
            'user_id' => $model->user_id,
            'deck_id' => $model->deck_id,
            'mode' => $model->mode,
            'started_at_ms' => $model->started_at_ms,
            'ended_at_ms' => $model->ended_at_ms,
            'cards_reviewed' => $model->cards_reviewed,
            'accuracy_pct' => $model->accuracy_pct,
            'mastery_delta' => $model->mastery_delta,
            'updated_at_ms' => $model->updated_at_ms,
            'deleted_at_ms' => $model->deleted_at_ms,
        ];
    }
}
