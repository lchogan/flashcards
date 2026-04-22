<?php

declare(strict_types=1);

/**
 * SyncPullController — handles authenticated server → client record pulls.
 *
 * Purpose:
 *   Accepts a `since` timestamp and a comma-separated list of entity keys from
 *   an authenticated client, delegates entity-level read logic to SyncPullService,
 *   and returns a map of changed records alongside pagination metadata and the
 *   current server clock.
 *
 * Dependencies:
 *   - App\Services\Sync\SyncPullService (reader registry and pull logic)
 *   - Illuminate\Http\Request (query parameters, authenticated user)
 *
 * Key concepts:
 *   - Invokable single-action controller; registered via __invoke.
 *   - `since` query param is a millisecond timestamp (integer); defaults to 0
 *     so an initial full sync requires no special client handling.
 *   - `entities` query param is a comma-separated list (e.g. "decks,topics").
 *   - `next_since` in the response is the max updated_at seen; the client
 *     should store this and send it as `since` on the next pull.
 *   - `has_more` signals that at least one entity's result was truncated;
 *     the client should re-pull immediately with the same `since`.
 */

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Sync\SyncPullService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncPullController extends Controller
{
    public function __construct(private readonly SyncPullService $service) {}

    /**
     * Handle a sync pull request.
     *
     * Parses `since` and `entities` from the query string, fetches changed
     * records via the pull service, and returns the record map with server
     * clock and pagination metadata.
     *
     * @param  Request  $request  Authenticated request with `since` (ms) and `entities` (csv) query params.
     * @return JsonResponse JSON body: {server_clock_ms: int, records: object, has_more: bool, next_since: int}
     */
    public function __invoke(Request $request): JsonResponse
    {
        $since = (int) $request->query('since', '0');
        $entityKeys = array_filter(explode(',', (string) $request->query('entities', '')));

        $result = $this->service->pull($request->user(), $since, $entityKeys);

        return response()->json([
            'server_clock_ms' => (int) (microtime(true) * 1000),
            'records' => $result->records,
            'has_more' => $result->hasMore,
            'next_since' => $result->nextSince,
        ]);
    }
}
