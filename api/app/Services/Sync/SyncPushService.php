<?php

declare(strict_types=1);

/**
 * Sync push service layer — upserter registry pattern.
 *
 * Purpose:
 *   Provides the core machinery for applying client-side record changes on the
 *   server. SyncPushService maintains a registry of entity-key → upserter class
 *   mappings. For each incoming record batch, it resolves the correct upserter
 *   via the service container and delegates row-level upsert logic to it.
 *
 * Dependencies:
 *   - App\Models\User (Eloquent user model, ownership scoping)
 *   - Laravel service container (app()) for upserter resolution
 *
 * Key concepts:
 *   - "Entity key" is the top-level key in the client's `records` payload
 *     (e.g. "decks", "cards"). Each maps to a concrete RecordUpserter.
 *   - Unknown entity keys are silently skipped (forward-compatible clients).
 *   - RecordUpserter implementations are resolved fresh per-row via app(), so
 *     each upserter can declare its own constructor dependencies.
 *   - Multi-class file: PSR-4 autoloads SyncPushService by filename; sibling
 *     types (SyncPushResult, RecordUpserter, UpsertResult) load alongside it.
 */

namespace App\Services\Sync;

use App\Models\User;

/**
 * Value object returned by SyncPushService::apply().
 *
 * Carries the count of accepted records and details of any rejections
 * encountered during the push operation.
 */
final class SyncPushResult
{
    /**
     * @param  int  $accepted  Number of records successfully upserted.
     * @param  list<array{id: string, reason: string}>  $rejected  Records that could not be applied.
     */
    public function __construct(public int $accepted, public array $rejected) {}
}

/**
 * Orchestrates incoming sync records against registered upserters.
 *
 * Register entity-key → upserter-class mappings via register(), then call
 * apply() on each authenticated push request. Unknown entity keys are skipped
 * so newer clients can push entities the server doesn't yet understand.
 */
final class SyncPushService
{
    /** @var array<string, class-string<RecordUpserter>> */
    private array $upserters = [];

    /**
     * Register an upserter class for a given entity key.
     *
     * @param  string  $entityKey  Top-level key in the client `records` payload (e.g. "decks").
     * @param  class-string<RecordUpserter>  $upserterClass  Concrete upserter to resolve via the container.
     */
    public function register(string $entityKey, string $upserterClass): void
    {
        $this->upserters[$entityKey] = $upserterClass;
    }

    /**
     * Apply a batch of client records, dispatching each to the correct upserter.
     *
     * Unknown entity keys are silently skipped. If an upserter rejects a row,
     * the rejection is recorded and iteration continues.
     *
     * @param  User  $user  Authenticated user; passed to each upserter for ownership scoping.
     * @param  array<string, array<int, array<string, mixed>>>  $records  Keyed by entity, value is a list of row payloads.
     * @return SyncPushResult Aggregate counts of accepted and rejected records.
     */
    public function apply(User $user, array $records): SyncPushResult
    {
        $accepted = 0;
        $rejected = [];

        foreach ($records as $entityKey => $rows) {
            $upserterClass = $this->upserters[$entityKey] ?? null;
            if ($upserterClass === null) {
                continue;
            }

            /** @var RecordUpserter $upserter */
            $upserter = app($upserterClass);
            foreach ($rows as $row) {
                $result = $upserter->upsert($user, $row);
                if ($result->accepted) {
                    $accepted++;
                } else {
                    $rejected[] = ['id' => (string) ($row['id'] ?? ''), 'reason' => $result->reason ?? 'unknown'];
                }
            }
        }

        return new SyncPushResult(accepted: $accepted, rejected: $rejected);
    }
}

/**
 * Contract for entity-specific upsert logic.
 *
 * Each concrete implementation handles one entity type (e.g. decks, cards).
 * Implementations are resolved via the Laravel service container, so
 * constructor injection is supported.
 */
interface RecordUpserter
{
    /**
     * Attempt to upsert a single record row for the given user.
     *
     * @param  User  $user  Owner of the record.
     * @param  array<string, mixed>  $row  Raw record payload from the client.
     * @return UpsertResult Whether the row was accepted or rejected (with reason).
     */
    public function upsert(User $user, array $row): UpsertResult;
}

/**
 * Value object returned by RecordUpserter::upsert().
 *
 * A rejected result should always carry a reason to aid client-side debugging.
 */
final class UpsertResult
{
    /**
     * @param  bool  $accepted  True if the row was successfully upserted.
     * @param  string|null  $reason  Human-readable rejection reason; null when accepted.
     */
    public function __construct(public bool $accepted, public ?string $reason = null) {}
}
