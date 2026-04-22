<?php

declare(strict_types=1);

/**
 * Topic upserter — last-write-wins upsert for Topic records.
 *
 * Purpose:
 *   Applies a single client-side Topic record to the server database using a
 *   last-write-wins (LWW) strategy keyed on updated_at_ms. Enforces ownership
 *   so a user can only modify their own topics.
 *
 * Dependencies:
 *   - App\Models\Topic (Eloquent model, HasUuids)
 *   - App\Models\User (ownership scoping)
 *   - App\Services\Sync\RecordUpserter (interface contract)
 *   - App\Services\Sync\UpsertResult (return value object)
 *
 * Key concepts:
 *   - LWW rule: incoming row is rejected when existing updated_at_ms >= incoming updated_at_ms.
 *   - Forbidden: a row whose UUID exists but belongs to a different user is rejected.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Models\Topic;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

/**
 * Upserts a single Topic record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "topics" entity key.
 */
final class TopicUpserter implements RecordUpserter
{
    /**
     * Attempt to upsert a Topic row using last-write-wins conflict resolution.
     *
     * LWW rule: if an existing row's updated_at_ms is >= the incoming value,
     * the update is considered stale and rejected with reason "stale". This
     * ensures a slower client cannot overwrite newer server state.
     *
     * @param  User  $user  Authenticated owner; used to scope creation and enforce access.
     * @param  array<string, mixed>  $row  Raw record payload from the client push request.
     * @return UpsertResult Accepted (true) or rejected (false) with a reason string.
     */
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $incoming = (int) ($row['updated_at_ms'] ?? 0);

        if ($id === '') {
            return new UpsertResult(false, 'missing_id');
        }

        $existing = Topic::find($id);

        if ($existing && $existing->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }

        if ($existing && $existing->updated_at_ms >= $incoming) {
            return new UpsertResult(false, 'stale');
        }

        // Use firstOrNew + explicit id assignment to avoid HasUuids overwriting the
        // client-supplied UUID during mass-assignment (id is not in $fillable, so
        // updateOrCreate's where-clause id would not reach setUniqueIds' empty check).
        $topic = Topic::firstOrNew(['id' => $id]);
        $topic->id = $id;
        $topic->fill([
            'user_id' => $user->id,
            'name' => (string) ($row['name'] ?? ''),
            'color_hint' => $row['color_hint'] ?? null,
            'updated_at_ms' => $incoming,
            'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
        ]);
        $topic->save();

        return new UpsertResult(true);
    }
}
