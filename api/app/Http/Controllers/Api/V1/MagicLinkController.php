<?php

declare(strict_types=1);

/**
 * MagicLinkController — POST /api/v1/auth/magic-link/{request,consume}.
 *
 * Purpose:
 *   Drive the two-leg email magic-link flow. `request()` accepts an email,
 *   mints a one-time token, and queues the delivery job. `consume()`
 *   exchanges a valid token for an access/refresh token pair and either
 *   finds or provisions the backing email-auth User.
 *
 * Dependencies:
 *   - App\Services\Auth\MagicLinkService (token issuance + persistence).
 *   - App\Jobs\SendMagicLinkEmail (queued email delivery).
 *   - App\Models\PendingEmailAuth (token row lookup + consumption marker).
 *   - App\Models\User (email-auth user provisioning).
 *   - Laravel Sanctum personal access tokens (via HasApiTokens on User).
 *
 * Key concepts:
 *   - Rate limit (5/hr) is applied to `request` at the route layer via
 *     Laravel's `throttle` middleware. See routes/api.php.
 *   - `request` is intentionally thin: validate, issue, dispatch, return 204.
 *     No user lookup happens there — that's deferred to consume.
 *   - `consume` returns HTTP 410 Gone for unknown, expired, or already-used
 *     tokens; successful exchanges issue a 15-minute access token and a
 *     90-day refresh token scoped to `auth:refresh`.
 */

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Jobs\SendMagicLinkEmail;
use App\Models\PendingEmailAuth;
use App\Models\User;
use App\Services\Auth\MagicLinkService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class MagicLinkController extends Controller
{
    public function __construct(private readonly MagicLinkService $service) {}

    /**
     * Handle a magic-link request.
     *
     * @param  Request  $request  Inbound HTTP request. Must carry `email`.
     * @return JsonResponse 204 No Content on success; 422 on validation error;
     *                      429 when rate-limited (handled by middleware).
     */
    public function request(Request $request): JsonResponse
    {
        $validated = $request->validate(['email' => ['required', 'email']]);

        $issued = $this->service->issue($validated['email']);

        SendMagicLinkEmail::dispatch($validated['email'], $issued['token']);

        return response()->json(status: 204);
    }

    /**
     * Exchange a one-time magic-link token for session credentials.
     *
     * Looks up the pending-auth row by sha256(token). Rejects with 410 Gone
     * for unknown, already-consumed, or expired tokens. On success, finds or
     * creates the email-auth User, marks the token consumed, and issues an
     * access token (15m) + refresh token (90d, `auth:refresh` scope).
     *
     * @param  Request  $request  Inbound HTTP request. Must carry `token`.
     * @return JsonResponse 200 with {access_token, refresh_token, user};
     *                      410 for unknown/expired/consumed tokens;
     *                      422 on validation error.
     */
    public function consume(Request $request): JsonResponse
    {
        $validated = $request->validate(['token' => ['required', 'string']]);
        $hash = hash('sha256', $validated['token']);

        $pending = PendingEmailAuth::where('token_hash', $hash)->first();
        abort_if($pending === null, 410, 'Invalid token');
        abort_if($pending->consumed_at !== null, 410, 'Token already used');
        abort_if($pending->expires_at->isPast(), 410, 'Token expired');

        $user = User::firstOrCreate(
            ['auth_provider' => 'email', 'email' => $pending->email],
            ['auth_provider_id' => (string) Str::orderedUuid(), 'updated_at_ms' => now()->valueOf()],
        );

        $pending->update(['consumed_at' => now()]);

        $access = $user->createToken('ios', ['*'], now()->addMinutes(15));
        $refresh = $user->createToken('refresh', ['auth:refresh'], now()->addDays(90));

        return response()->json([
            'access_token' => $access->plainTextToken,
            'refresh_token' => $refresh->plainTextToken,
            'user' => ['id' => $user->id, 'email' => $user->email],
        ]);
    }
}
