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
 *   - App\Services\Sync\AbstractCursorReader (base class; handles pagination,
 *     cursor computation, and the [rows, hasMore, maxUpdatedMs] tuple)
 *
 * Key concepts:
 *   - Ownership: scoped by user_id directly on the decks table.
 *   - Pagination: one-extra-row trick; see AbstractCursorReader.
 *   - nextSince: max updated_at_ms in page → client's next `since`.
 *   - Ordered by updated_at_ms ASC so cursored pagination is stable.
 */

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\User;
use App\Services\Sync\AbstractCursorReader;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Reads Deck records for the authenticated user updated after a given timestamp.
 *
 * Implements the RecordReader contract for the "decks" entity key via
 * AbstractCursorReader. Only entity-specific concerns are declared here:
 * model class, ownership scope, and row projection.
 */
final class DeckReader extends AbstractCursorReader
{
    /**
     * @return class-string<Model>
     */
    protected function modelClass(): string
    {
        return Deck::class;
    }

    /**
     * Scope the query to decks owned by the authenticated user.
     *
     * @param  Builder<Model>  $query  Base query for the Deck model.
     * @param  User  $user  Authenticated user.
     * @return Builder<Model> Scoped query.
     */
    protected function scopeForUser(Builder $query, User $user): Builder
    {
        return $query->where('user_id', $user->id);
    }

    /**
     * Project a Deck model into the wire-format row.
     *
     * @param  Model  $model  Hydrated Deck instance.
     * @return array<string, mixed> Wire-format row.
     */
    protected function projectRow(Model $model): array
    {
        assert($model instanceof Deck);

        return [
            'id' => $model->id,
            'topic_id' => $model->topic_id,
            'title' => $model->title,
            'description' => $model->description,
            'accent_color' => $model->accent_color,
            'default_study_mode' => $model->default_study_mode,
            'card_count' => $model->card_count,
            'last_studied_at_ms' => $model->last_studied_at_ms,
            'updated_at_ms' => $model->updated_at_ms,
            'deleted_at_ms' => $model->deleted_at_ms,
        ];
    }
}
