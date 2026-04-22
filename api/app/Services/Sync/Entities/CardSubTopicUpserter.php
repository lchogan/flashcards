<?php

declare(strict_types=1);

/**
 * CardSubTopic upserter — last-write-wins upsert for CardSubTopic join records.
 *
 * Purpose:
 *   Applies a single client-side CardSubTopic record to the server database using a
 *   last-write-wins (LWW) strategy keyed on updated_at_ms. Enforces a two-part
 *   ownership constraint: (1) the referenced card's deck must be owned by the
 *   authenticated user, and (2) the referenced sub-topic must belong to the same
 *   deck as the card. Cross-deck associations are structurally invalid.
 *
 * Dependencies:
 *   - App\Models\Card (parent entity; ownership resolved via card->deck->user_id)
 *   - App\Models\CardSubTopic (Eloquent model, HasUuids)
 *   - App\Models\SubTopic (must share deck_id with the card)
 *   - App\Models\User (ownership scoping)
 *   - App\Services\Sync\RecordUpserter (interface contract)
 *   - App\Services\Sync\UpsertResult (return value object)
 *
 * Key concepts:
 *   - LWW rule: incoming row is rejected when existing updated_at_ms >= incoming updated_at_ms.
 *   - Two-part ownership check:
 *       (1) card must exist and its deck must be owned by the authenticated user.
 *       (2) sub-topic must exist and its deck_id must match the card's deck_id.
 *   - Stateless: no constructor dependencies; safe to resolve per-request via app().
 */

namespace App\Services\Sync\Entities;

use App\Models\Card;
use App\Models\CardSubTopic;
use App\Models\SubTopic;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

/**
 * Upserts a single CardSubTopic record for the authenticated user.
 *
 * Implements the RecordUpserter contract for the "card_sub_topics" entity key.
 * Ownership is enforced via the card's parent deck and cross-deck validation
 * of the sub-topic — neither the cards nor sub_topics tables carry a direct user_id.
 */
final class CardSubTopicUpserter implements RecordUpserter
{
    /**
     * Attempt to upsert a CardSubTopic row using last-write-wins conflict resolution.
     *
     * LWW rule: if an existing row's updated_at_ms is >= the incoming value,
     * the update is considered stale and rejected with reason "stale". This
     * ensures a slower client cannot overwrite newer server state.
     *
     * Two-part ownership check:
     *   (1) The card's deck must be owned by the authenticated user — this is the
     *       primary ownership gate (there is no user_id on cards or card_sub_topics).
     *   (2) The sub-topic's deck_id must match the card's deck_id — an association
     *       that spans two different decks is structurally invalid and rejected.
     *
     * @param  User  $user  Authenticated owner; used to verify card/deck ownership.
     * @param  array<string, mixed>  $row  Raw record payload from the client push request.
     * @return UpsertResult Accepted (true) or rejected (false) with a reason string.
     */
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $cardId = (string) ($row['card_id'] ?? '');
        $subTopicId = (string) ($row['sub_topic_id'] ?? '');
        $incoming = (int) ($row['updated_at_ms'] ?? 0);

        if ($id === '' || $cardId === '' || $subTopicId === '') {
            return new UpsertResult(false, 'missing_id');
        }

        $card = Card::with('deck')->find($cardId);

        // (1) Card must exist and its deck must be owned by the authenticated user.
        // (2) Sub-topic must exist and belong to the same deck as the card —
        //     cross-deck associations are structurally invalid and never permitted.
        if (! $card || $card->deck->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }

        $st = SubTopic::find($subTopicId);
        if (! $st || $st->deck_id !== $card->deck_id) {
            return new UpsertResult(false, 'forbidden');
        }

        $existing = CardSubTopic::find($id);
        if ($existing && $existing->updated_at_ms >= $incoming) {
            return new UpsertResult(false, 'stale');
        }

        // Use firstOrNew + explicit id assignment to avoid HasUuids overwriting the
        // client-supplied UUID during mass-assignment (id is not in $fillable, so
        // updateOrCreate's where-clause id would not reach setUniqueIds' empty check).
        $assoc = CardSubTopic::firstOrNew(['id' => $id]);
        $assoc->id = $id;
        $assoc->fill([
            'card_id' => $cardId,
            'sub_topic_id' => $subTopicId,
            'updated_at_ms' => $incoming,
            'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
        ]);
        $assoc->save();

        return new UpsertResult(true);
    }
}
