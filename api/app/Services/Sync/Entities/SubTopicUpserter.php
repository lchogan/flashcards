<?php

declare(strict_types=1);

/**
 * SubTopic upserter — last-write-wins upsert for SubTopic records.
 *
 * Purpose:
 *   Applies a single client-side SubTopic record to the server database using a
 *   last-write-wins (LWW) strategy keyed on updated_at_ms. Enforces ownership
 *   indirectly: ownership is determined by the parent Deck's user_id rather than
 *   a direct user_id column on the sub_topics table.
 *
 * Dependencies:
 *   - App\Models\SubTopic (Eloquent model, HasUuids)
 *   - App\Models\Deck (parent entity; ownership resolved via deck->user_id)
 *   - App\Models\User (ownership scoping)
 *   - App\Services\Sync\RecordUpserter (interface contract)
 *   - App\Services\Sync\UpsertResult (return value object)
 *
 * Key concepts:
 *   - LWW rule: incoming row is rejected when existing updated_at_ms >= incoming updated_at_ms.
 *   - Forbidden: the referenced deck must exist and be owned by the authenticated user.
 *     Unlike top-level entities (Topic, Deck), there is no user_id column on sub_topics;
 *     ownership is enforced via the deck's user_id.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\SubTopic;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

/**
 * Upserts a single SubTopic record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "sub_topics" entity key.
 * Ownership is enforced via the parent deck's user_id — the sub_topics table
 * has no direct user_id column.
 */
final class SubTopicUpserter implements RecordUpserter
{
    /**
     * Attempt to upsert a SubTopic row using last-write-wins conflict resolution.
     *
     * LWW rule: if an existing row's updated_at_ms is >= the incoming value,
     * the update is considered stale and rejected with reason "stale". This
     * ensures a slower client cannot overwrite newer server state.
     *
     * Ownership check: the referenced deck_id must belong to the authenticated
     * user. If the deck does not exist or belongs to another user, the row is
     * rejected with reason "forbidden".
     *
     * @param  User  $user  Authenticated owner; used to verify deck ownership.
     * @param  array<string, mixed>  $row  Raw record payload from the client push request.
     * @return UpsertResult Accepted (true) or rejected (false) with a reason string.
     */
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $deckId = (string) ($row['deck_id'] ?? '');
        $incoming = (int) ($row['updated_at_ms'] ?? 0);

        if ($id === '' || $deckId === '') {
            return new UpsertResult(false, 'missing_id');
        }

        $deck = Deck::find($deckId);
        if (! $deck || $deck->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }

        $existing = SubTopic::find($id);
        if ($existing && $existing->updated_at_ms >= $incoming) {
            return new UpsertResult(false, 'stale');
        }

        // Use firstOrNew + explicit id assignment to avoid HasUuids overwriting the
        // client-supplied UUID during mass-assignment (id is not in $fillable, so
        // updateOrCreate's where-clause id would not reach setUniqueIds' empty check).
        $subTopic = SubTopic::firstOrNew(['id' => $id]);
        $subTopic->id = $id;
        $subTopic->fill([
            'deck_id' => $deckId,
            'name' => (string) ($row['name'] ?? ''),
            'position' => (int) ($row['position'] ?? 0),
            'color_hint' => $row['color_hint'] ?? null,
            'updated_at_ms' => $incoming,
            'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
        ]);
        $subTopic->save();

        return new UpsertResult(true);
    }
}
