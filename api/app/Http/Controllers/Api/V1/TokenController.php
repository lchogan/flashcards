<?php

declare(strict_types=1);

/**
 * TokenController — POST /api/v1/auth/refresh.
 *
 * Purpose:
 *   Exchange a valid refresh token (scoped `auth:refresh`) for a freshly
 *   issued access+refresh token pair. Every successful call rotates the
 *   refresh token: the presented refresh is deleted, and a new refresh is
 *   issued alongside a new 15-minute access token.
 *
 * Dependencies:
 *   - Laravel\Sanctum\PersonalAccessToken (lookup by plaintext).
 *   - App\Models\User (HasApiTokens::createToken for new pair).
 *
 * Key concepts:
 *   - This route is intentionally unauthenticated from Sanctum's perspective:
 *     refresh tokens carry the `auth:refresh` ability, which the access-token
 *     middleware (`auth:sanctum`) would reject. Auth is verified manually in
 *     the controller.
 *   - Three rejection conditions, each 401: token not found, token lacks the
 *     `auth:refresh` ability, token is past its `expires_at`.
 *   - Rotation semantics: prior access tokens issued by earlier pairs remain
 *     valid until their 15-minute TTL expires; we do NOT bulk-revoke on
 *     rotation.
 */

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;

class TokenController extends Controller
{
    /**
     * Rotate a refresh token into a fresh access+refresh pair.
     *
     * Looks up the presented refresh token by plaintext, verifies it carries
     * the `auth:refresh` ability and has not expired, then issues a new pair
     * and deletes the presented refresh row.
     *
     * @param  Request  $request  Inbound HTTP request. Must carry `refresh_token`.
     * @return JsonResponse 200 with {access_token, refresh_token};
     *                      401 for missing/wrong-ability/expired tokens;
     *                      422 on validation error.
     */
    public function refresh(Request $request): JsonResponse
    {
        $validated = $request->validate(['refresh_token' => ['required', 'string']]);

        $token = PersonalAccessToken::findToken($validated['refresh_token']);
        // Split into three aborts so PHPStan can narrow $token to non-null
        // after the first check (same pattern used in 0.35's PendingEmailAuth lookup).
        abort_if($token === null, 401);
        abort_unless(in_array('auth:refresh', $token->abilities, true), 401);
        abort_if($token->expires_at !== null && $token->expires_at->isPast(), 401);

        // $token->tokenable returns a bare Model by default; narrow to User so
        // PHPStan accepts the createToken() calls below.
        $user = $token->tokenable;
        if (! $user instanceof User) {
            abort(401);
        }

        $access = $user->createToken('ios', ['*'], now()->addMinutes(15));
        $newRefresh = $user->createToken('refresh', ['auth:refresh'], now()->addDays(90));
        $token->delete();

        return response()->json([
            'access_token' => $access->plainTextToken,
            'refresh_token' => $newRefresh->plainTextToken,
        ]);
    }
}
