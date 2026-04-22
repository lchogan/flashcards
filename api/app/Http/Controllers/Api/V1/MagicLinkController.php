<?php

declare(strict_types=1);

/**
 * MagicLinkController — POST /api/v1/auth/magic-link/request.
 *
 * Purpose:
 *   Accept an email address, mint a single-use magic-link token, and queue
 *   an email with the sign-in URL. Responds 204 so the client cannot tell
 *   from the HTTP response whether the email is already registered.
 *
 * Dependencies:
 *   - App\Services\Auth\MagicLinkService (token issuance + persistence).
 *   - App\Jobs\SendMagicLinkEmail (queued email delivery).
 *
 * Key concepts:
 *   - Rate limit (5/hr) is applied at the route layer via Laravel's
 *     `throttle` middleware. See routes/api.php.
 *   - The controller is intentionally thin: validate, issue, dispatch,
 *     return 204. No user lookup happens here — that's the consume step.
 */

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Jobs\SendMagicLinkEmail;
use App\Services\Auth\MagicLinkService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

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
}
