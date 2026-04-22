<?php

declare(strict_types=1);

/**
 * SyncPushController — handles authenticated client → server record pushes.
 *
 * Purpose:
 *   Accepts a batch of changed records from an authenticated client, delegates
 *   entity-level upsert logic to SyncPushService, and returns a summary of
 *   accepted/rejected counts alongside the current server clock.
 *
 * Dependencies:
 *   - App\Services\Sync\SyncPushService (upserter registry and apply logic)
 *   - Illuminate\Http\Request (validated input, authenticated user)
 *
 * Key concepts:
 *   - Invokable single-action controller; registered via __invoke.
 *   - `client_clock_ms` is validated but not yet persisted — reserved for
 *     future conflict detection (Task 1.5+).
 *   - `server_clock_ms` in the response lets the client advance its local
 *     high-water mark after a successful push.
 */

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Sync\SyncPushService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncPushController extends Controller
{
    public function __construct(private readonly SyncPushService $service) {}

    /**
     * Handle a sync push request.
     *
     * Validates the payload, applies all records via the push service, and
     * returns aggregate accepted/rejected counts with the current server clock.
     *
     * @param  Request  $request  Authenticated request carrying client_clock_ms and records.
     * @return JsonResponse JSON body: {accepted: int, rejected: array, server_clock_ms: int}
     */
    public function __invoke(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'client_clock_ms' => ['required', 'integer'],
            // 'present' (not 'required') so an empty records object {} passes validation;
            // 'required' rejects empty arrays in Laravel, but clients legitimately send {}
            // when there are no pending changes.
            'records' => ['present', 'array'],
        ]);

        $result = $this->service->apply(
            user: $request->user(),
            records: $validated['records'],
        );

        return response()->json([
            'accepted' => $result->accepted,
            'rejected' => $result->rejected,
            'server_clock_ms' => (int) (microtime(true) * 1000),
        ]);
    }
}
