<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Reminder;
use App\Services\Entitlements\EntitlementChecker;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Reminder CRUD for the authenticated user.
 *
 * - GET    /v1/reminders        → list user's reminders
 * - POST   /v1/reminders        → create (gated by `reminders.add`, 402 on cap)
 * - PATCH  /v1/reminders/{id}   → toggle enabled / change time
 * - DELETE /v1/reminders/{id}   → delete
 *
 * The server persists the time-of-day and enabled flag; the client is
 * responsible for scheduling the actual UNUserNotification.
 */
class ReminderController extends Controller
{
    public function __construct(private readonly EntitlementChecker $checker) {}

    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'reminders' => $request->user()->reminders()->orderBy('time_local')->get(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $check = $this->checker->can($request->user(), 'reminders.add');
        if (! $check->allowed) {
            return response()->json([
                'reason' => $check->reason,
                'limit' => $check->limit,
            ], 402);
        }

        $data = $request->validate([
            'time_local' => ['required', 'date_format:H:i'],
            'enabled' => ['sometimes', 'boolean'],
        ]);

        $reminder = $request->user()->reminders()->create([
            'time_local' => $data['time_local'],
            'enabled' => $data['enabled'] ?? true,
            'updated_at_ms' => (int) now()->valueOf(),
        ]);

        return response()->json($reminder, 201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $reminder = Reminder::where('user_id', $request->user()->id)->findOrFail($id);

        $data = $request->validate([
            'time_local' => ['sometimes', 'date_format:H:i'],
            'enabled' => ['sometimes', 'boolean'],
        ]);

        $reminder->fill($data);
        $reminder->updated_at_ms = (int) now()->valueOf();
        $reminder->save();

        return response()->json($reminder);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $reminder = Reminder::where('user_id', $request->user()->id)->findOrFail($id);
        $reminder->delete();

        return response()->json(status: 204);
    }
}
