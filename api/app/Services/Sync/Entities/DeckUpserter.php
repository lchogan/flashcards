<?php

declare(strict_types=1);

/**
 * Deck upserter — last-write-wins upsert for Deck records.
 *
 * Purpose:
 *   Applies a single client-side Deck record to the server database using a
 *   last-write-wins (LWW) strategy keyed on updated_at_ms. Enforces ownership
 *   so a user can only modify their own decks.
 *
 * Dependencies:
 *   - App\Models\Deck (Eloquent model, HasUuids)
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

use App\Models\Deck;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

/**
 * Upserts a single Deck record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "decks" entity key.
 */
final class DeckUpserter implements RecordUpserter
{
    /**
     * Attempt to upsert a Deck row using last-write-wins conflict resolution.
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

        $existing = Deck::find($id);

        if ($existing && $existing->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }

        if ($existing && $existing->updated_at_ms >= $incoming) {
            return new UpsertResult(false, 'stale');
        }

        // Use firstOrNew + explicit id assignment to avoid HasUuids overwriting the
        // client-supplied UUID during mass-assignment (id is not in $fillable, so
        // updateOrCreate's where-clause id would not reach setUniqueIds' empty check).
        $deck = Deck::firstOrNew(['id' => $id]);
        $deck->id = $id;
        $deck->fill([
            'user_id' => $user->id,
            'topic_id' => $row['topic_id'] ?? null,
            'title' => (string) ($row['title'] ?? ''),
            'description' => $row['description'] ?? null,
            'accent_color' => (string) ($row['accent_color'] ?? 'amber'),
            'default_study_mode' => (string) ($row['default_study_mode'] ?? 'smart'),
            'card_count' => (int) ($row['card_count'] ?? 0),
            'last_studied_at_ms' => isset($row['last_studied_at_ms']) ? (int) $row['last_studied_at_ms'] : null,
            'updated_at_ms' => $incoming,
            'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
        ]);
        $deck->save();

        return new UpsertResult(true);
    }
}
