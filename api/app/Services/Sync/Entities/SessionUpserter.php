<?php

declare(strict_types=1);

/**
 * Session upserter — last-write-wins upsert for Session (study_sessions) records.
 *
 * Purpose:
 *   Applies a single client-side Session record to the server database using a
 *   last-write-wins (LWW) strategy keyed on updated_at_ms. Enforces that the
 *   referenced deck belongs to the authenticated user so sessions cannot be
 *   attached to decks the user does not own.
 *
 * Dependencies:
 *   - App\Models\Deck (ownership check via deck->user_id)
 *   - App\Models\Session (Eloquent model, HasUuids, table=study_sessions)
 *   - App\Models\User (authenticated owner)
 *   - App\Services\Sync\RecordUpserter (interface contract)
 *   - App\Services\Sync\UpsertResult (return value object)
 *
 * Key concepts:
 *   - LWW rule: incoming row is rejected when existing updated_at_ms >= incoming updated_at_ms.
 *   - Ownership: the referenced deck must exist and its user_id must match the
 *     authenticated user. Missing or foreign decks yield a "forbidden" result.
 *   - UUID preservation: id is not in $fillable; we use firstOrNew + explicit
 *     $model->id assignment so HasUuids does not regenerate the client-supplied UUID.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\Session;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

/**
 * Upserts a single Session record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "sessions" entity key.
 * Ownership is enforced by verifying the referenced deck belongs to the user.
 */
final class SessionUpserter implements RecordUpserter
{
    /**
     * Attempt to upsert a Session row using last-write-wins conflict resolution.
     *
     * Guard order:
     *   1. Missing id or deck_id → missing_id
     *   2. Deck not found or deck.user_id != user.id → forbidden
     *   3. Stale LWW check (existing updated_at_ms >= incoming) → stale
     *   4. firstOrNew + explicit id + fill + save
     *
     * UUID preservation: id is not in $fillable. We assign $session->id
     * explicitly before save() to prevent HasUuids from regenerating it.
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

        // Ownership: the deck must exist and belong to the authenticated user.
        $deck = Deck::find($deckId);
        if (! $deck || $deck->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }

        $existing = Session::find($id);

        // LWW: reject stale writes regardless of whether the row was just found.
        if ($existing && $existing->updated_at_ms >= $incoming) {
            return new UpsertResult(false, 'stale');
        }

        // Use firstOrNew + explicit id assignment to avoid HasUuids overwriting the
        // client-supplied UUID (id is not in $fillable, so updateOrCreate's where-clause
        // id would not reach setUniqueIds' empty check).
        $session = Session::firstOrNew(['id' => $id]);
        $session->id = $id;
        $session->fill([
            'user_id' => $user->id,
            'deck_id' => $deckId,
            'mode' => (string) ($row['mode'] ?? 'smart'),
            'started_at_ms' => (int) ($row['started_at_ms'] ?? 0),
            'ended_at_ms' => isset($row['ended_at_ms']) ? (int) $row['ended_at_ms'] : null,
            'cards_reviewed' => (int) ($row['cards_reviewed'] ?? 0),
            'accuracy_pct' => (float) ($row['accuracy_pct'] ?? 0),
            'mastery_delta' => (float) ($row['mastery_delta'] ?? 0),
            'updated_at_ms' => $incoming,
            'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
        ]);
        $session->save();

        return new UpsertResult(true);
    }
}
