<?php

declare(strict_types=1);

/**
 * Sync pull service layer — reader registry pattern.
 *
 * Purpose:
 *   Provides the core machinery for fetching server-side records changed since
 *   a given timestamp and returning them to the client. SyncPullService maintains
 *   a registry of entity-key → reader class mappings. For each requested entity,
 *   it resolves the correct reader via the service container and delegates
 *   row-level fetch logic to it.
 *
 * Dependencies:
 *   - App\Models\User (Eloquent user model, ownership scoping)
 *   - Laravel service container (app()) for reader resolution
 *
 * Key concepts:
 *   - "Entity key" is the top-level key in the response `records` map
 *     (e.g. "decks", "topics"). Each maps to a concrete RecordReader.
 *   - Unregistered entity keys are initialised to an empty array (forward-
 *     compatible clients can request entities the server doesn't yet serve).
 *   - RecordReader implementations are resolved once per entity key per
 *     request via app(), so each reader can declare its own constructor
 *     dependencies. Reader classes should be stateless or request-scoped —
 *     don't bind a reader as a container singleton, or per-request state
 *     will leak across requests via the shared SyncPullService registry.
 *   - Multi-class file: PSR-4 autoloads SyncPullService by filename; sibling
 *     types (SyncPullResult, RecordReader) load alongside it.
 */

namespace App\Services\Sync;

use App\Models\User;

/**
 * Value object returned by SyncPullService::pull().
 *
 * Carries the map of entity records fetched, a pagination flag, and the
 * maximum updated_at timestamp observed (used as the client's next `since`).
 */
final class SyncPullResult
{
    /**
     * @param  array<string, list<array<string,mixed>>>  $records  Keyed by entity; value is a list of row payloads.
     * @param  bool  $hasMore  True if any entity's result set was truncated by $pageSize.
     * @param  int  $nextSince  Millisecond timestamp the client should send as `since` on the next pull.
     */
    public function __construct(public array $records, public bool $hasMore, public int $nextSince) {}
}

/**
 * Orchestrates outgoing sync records via registered readers.
 *
 * Register entity-key → reader-class mappings via register(), then call
 * pull() on each authenticated pull request. Unregistered entity keys are
 * returned as empty arrays so newer clients can request entities the server
 * does not yet support.
 */
final class SyncPullService
{
    /** @var array<string, class-string<RecordReader>> */
    private array $readers = [];

    /**
     * Register a reader class for a given entity key.
     *
     * @param  string  $entityKey  Top-level key in the response `records` map (e.g. "decks").
     * @param  class-string<RecordReader>  $readerClass  Concrete reader to resolve via the container.
     */
    public function register(string $entityKey, string $readerClass): void
    {
        $this->readers[$entityKey] = $readerClass;
    }

    /**
     * Fetch records for the requested entities changed since the given timestamp.
     *
     * Unregistered entity keys produce an empty array entry. Pagination is
     * signalled per-entity; if any entity has more results the aggregate
     * $hasMore is true.
     *
     * @param  User  $user  Authenticated user; passed to each reader for ownership scoping.
     * @param  int  $since  Millisecond timestamp; only records updated after this are returned.
     * @param  array<int, string>  $entityKeys  Requested entity keys from the client query string.
     * @param  int  $pageSize  Maximum rows returned per entity per request.
     * @return SyncPullResult Aggregate record map, pagination flag, and next-since timestamp.
     */
    public function pull(User $user, int $since, array $entityKeys, int $pageSize = 500): SyncPullResult
    {
        $records = [];
        $hasMore = false;
        $maxUpdated = $since;

        foreach ($entityKeys as $entityKey) {
            $readerClass = $this->readers[$entityKey] ?? null;
            if ($readerClass === null) {
                $records[$entityKey] = [];

                continue;
            }

            /** @var RecordReader $reader */
            $reader = app($readerClass);
            [$rows, $entityHasMore, $maxForEntity] = $reader->read($user, $since, $pageSize);

            $records[$entityKey] = $rows;
            $hasMore = $hasMore || $entityHasMore;
            $maxUpdated = max($maxUpdated, $maxForEntity);
        }

        return new SyncPullResult(records: $records, hasMore: $hasMore, nextSince: $maxUpdated);
    }
}

/**
 * Contract for entity-specific read logic.
 *
 * Each concrete implementation handles one entity type (e.g. decks, topics).
 * Implementations are resolved via the Laravel service container, so
 * constructor injection is supported.
 */
interface RecordReader
{
    /**
     * Fetch records for the given user updated after $since, up to $pageSize rows.
     *
     * @param  User  $user  Owner of the records; used for ownership scoping.
     * @param  int  $since  Millisecond timestamp lower-bound (exclusive) for updated_at.
     * @param  int  $pageSize  Maximum number of rows to return.
     * @return array{0: list<array<string, mixed>>, 1: bool, 2: int}
     *                                                               A 3-tuple of [rows, hasMore, maxUpdatedMs].
     */
    public function read(User $user, int $since, int $pageSize): array;
}
