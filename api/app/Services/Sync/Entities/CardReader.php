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
 *   - App\Services\Sync\AbstractCursorReader (base class; handles pagination,
 *     cursor computation, and the [rows, hasMore, maxUpdatedMs] tuple)
 *
 * Key concepts:
 *   - Ownership: Card has no direct user_id column. Ownership is enforced
 *     by constraining deck_id to the set of deck IDs owned by the user, resolved
 *     via a subquery on $user->decks()->select('id'). This is why the User model
 *     must expose a decks() HasMany relation.
 *   - Pagination: one-extra-row trick; see AbstractCursorReader.
 *   - nextSince: max updated_at_ms in page → client's next `since`.
 *   - Ordered by updated_at_ms ASC so cursored pagination is stable.
 */

namespace App\Services\Sync\Entities;

use App\Models\Card;
use App\Models\User;
use App\Services\Sync\AbstractCursorReader;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Reads Card records accessible to the authenticated user updated after a given timestamp.
 *
 * Implements the RecordReader contract for the "cards" entity key via
 * AbstractCursorReader. Ownership is enforced via a whereIn subquery on the
 * user's owned deck IDs.
 */
final class CardReader extends AbstractCursorReader
{
    /**
     * @return class-string<Model>
     */
    protected function modelClass(): string
    {
        return Card::class;
    }

    /**
     * Scope the query to cards belonging to decks owned by the user.
     *
     * Uses a whereIn subquery on $user->decks()->select('id') so that ownership
     * is enforced without a JOIN — the User model must expose a decks() HasMany.
     *
     * @param  Builder<Model>  $query  Base query for the Card model.
     * @param  User  $user  Authenticated user.
     * @return Builder<Model> Scoped query.
     */
    protected function scopeForUser(Builder $query, User $user): Builder
    {
        return $query->whereIn('deck_id', $user->decks()->select('id'));
    }

    /**
     * Project a Card model into the wire-format row.
     *
     * @param  Model  $model  Hydrated Card instance.
     * @return array<string, mixed> Wire-format row.
     */
    protected function projectRow(Model $model): array
    {
        assert($model instanceof Card);

        return [
            'id' => $model->id,
            'deck_id' => $model->deck_id,
            'front_text' => $model->front_text,
            'back_text' => $model->back_text,
            'front_image_asset_id' => $model->front_image_asset_id,
            'back_image_asset_id' => $model->back_image_asset_id,
            'position' => $model->position,
            'stability' => $model->stability,
            'difficulty' => $model->difficulty,
            'state' => $model->state,
            'last_reviewed_at_ms' => $model->last_reviewed_at_ms,
            'due_at_ms' => $model->due_at_ms,
            'lapses' => $model->lapses,
            'reps' => $model->reps,
            'updated_at_ms' => $model->updated_at_ms,
            'deleted_at_ms' => $model->deleted_at_ms,
        ];
    }
}
