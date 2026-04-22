<?php

declare(strict_types=1);

/**
 * AppleAuthController — POST /api/v1/auth/apple.
 *
 * Purpose:
 *   Accept an Apple Sign In identity token from the iOS client, verify it via
 *   AppleIdentityVerifier, upsert the associated User by (auth_provider,
 *   auth_provider_id), and issue a short-lived Sanctum access token plus a
 *   long-lived refresh token.
 *
 * Dependencies:
 *   - App\Services\Auth\AppleIdentityVerifier (resolved via the container).
 *   - App\Http\Requests\AppleAuthRequest (input validation).
 *   - App\Models\User (with Laravel Sanctum's HasApiTokens trait).
 *
 * Key concepts:
 *   - Apple only returns the email on the first sign-in for a given user.
 *     On subsequent sign-ins we match on the composite unique index
 *     (auth_provider, auth_provider_id) so the email need not be resent.
 *   - Access token TTL: 15 minutes. Refresh token TTL: 90 days, scoped to
 *     `auth:refresh` so it can only be exchanged for a new access token.
 */

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\AppleAuthRequest;
use App\Models\User;
use App\Services\Auth\AppleIdentityVerifier;
use Illuminate\Http\JsonResponse;

class AppleAuthController extends Controller
{
    public function __construct(private readonly AppleIdentityVerifier $verifier) {}

    /**
     * Handle an Apple Sign In request.
     *
     * Verifies the submitted identity token, finds-or-creates the matching
     * user, and returns a short-lived access token plus a refresh token.
     *
     * @param  AppleAuthRequest  $request  Validated request carrying `identity_token`.
     * @return JsonResponse Payload: { access_token, refresh_token, user: { id, email } }.
     *
     * @throws \RuntimeException Bubbled from AppleIdentityVerifier on verification failure.
     */
    public function store(AppleAuthRequest $request): JsonResponse
    {
        $claims = $this->verifier->verify($request->string('identity_token')->toString());

        $user = User::firstOrCreate(
            ['auth_provider' => 'apple', 'auth_provider_id' => $claims->subject],
            ['email' => $claims->email ?? '', 'updated_at_ms' => now()->valueOf()],
        );

        $access = $user->createToken('ios', ['*'], now()->addMinutes(15));
        $refresh = $user->createToken('refresh', ['auth:refresh'], now()->addDays(90));

        return response()->json([
            'access_token' => $access->plainTextToken,
            'refresh_token' => $refresh->plainTextToken,
            'user' => ['id' => $user->id, 'email' => $user->email],
        ]);
    }
}
