<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * MeController — current user's profile endpoint.
 *
 * Purpose:
 *   Serves the authenticated user's profile document and applies validated
 *   patches to mutable fields. Bumps `updated_at_ms` on every successful patch
 *   so the profile participates in the sync LWW protocol.
 *
 * Dependencies:
 *   - App\Models\User (Eloquent user model, Sanctum auth)
 *   - Laravel validator for input validation
 */
class MeController extends Controller
{
    /**
     * Return the authenticated user's profile.
     */
    public function show(Request $request): JsonResponse
    {
        /** @var User $u */
        $u = $request->user();

        return response()->json([
            'id' => $u->id,
            'email' => $u->email,
            'name' => $u->name,
            'avatar_url' => $u->avatar_url,
            'daily_goal_cards' => $u->daily_goal_cards,
            'reminder_time_local' => $u->reminder_time_local,
            'reminder_enabled' => $u->reminder_enabled,
            'theme_preference' => $u->theme_preference,
            'subscription_status' => $u->subscription_status,
            'subscription_expires_at' => $u->subscription_expires_at?->toIso8601String(),
            'updated_at_ms' => $u->updated_at_ms,
        ]);
    }

    /**
     * Patch the authenticated user's mutable profile fields.
     *
     * Validates and persists only the allowed-list of fields; unknown fields
     * are silently ignored. Bumps `updated_at_ms` so the change propagates
     * via sync pull.
     */
    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:200'],
            'daily_goal_cards' => ['sometimes', 'integer', 'min:1', 'max:500'],
            'reminder_time_local' => ['sometimes', 'nullable', 'date_format:H:i'],
            'reminder_enabled' => ['sometimes', 'boolean'],
            'theme_preference' => ['sometimes', 'in:system,light,dark'],
        ]);

        $data['updated_at_ms'] = (int) (microtime(true) * 1000);

        /** @var User $u */
        $u = $request->user();
        $u->update($data);

        return $this->show($request);
    }

    /**
     * Register / overwrite the APNs device token for this user. Called by
     * iOS from `UIApplicationDelegate.didRegisterForRemoteNotificationsWithDeviceToken`
     * so the server can route SubscriptionRenewed / PaymentFailed to the
     * device. Idempotent; tokens rotate on device reinstall.
     */
    public function registerDeviceToken(Request $request): JsonResponse
    {
        $data = $request->validate([
            'device_token' => ['required', 'string', 'max:255'],
        ]);

        /** @var User $u */
        $u = $request->user();
        $u->update(['apn_device_token' => $data['device_token']]);

        return response()->json(status: 204);
    }
}
