<?php

declare(strict_types=1);

/**
 * MagicLinkRequestTest — feature coverage for POST /api/v1/auth/magic-link/request.
 *
 * Purpose:
 *   Verify the request endpoint stores a pending-auth row, queues the
 *   email-delivery job, and rejects further attempts once the throttle
 *   cap is reached.
 *
 * Key concepts:
 *   - Pest Feature suite auto-applies RefreshDatabase (see tests/Pest.php),
 *     so `pending_email_auths` starts empty per test.
 *   - `Queue::fake()` intercepts `dispatch()` since SendMagicLinkEmail
 *     implements ShouldQueue; the job is asserted without actually sending.
 *   - The throttle is keyed per-user/IP by Laravel's default middleware, so
 *     all six requests in the rate-limit test share one bucket.
 */

use App\Jobs\SendMagicLinkEmail;
use App\Models\PendingEmailAuth;
use Illuminate\Support\Facades\Queue;

test('POST /v1/auth/magic-link/request stores a pending auth and queues the email', function () {
    Queue::fake();

    $response = $this->postJson('/api/v1/auth/magic-link/request', ['email' => 'new@user.com']);

    $response->assertNoContent();
    expect(PendingEmailAuth::where('email', 'new@user.com')->exists())->toBeTrue();
    Queue::assertPushed(SendMagicLinkEmail::class);
});

test('rate-limits to 5 per hour per email', function () {
    for ($i = 0; $i < 5; $i++) {
        $this->postJson('/api/v1/auth/magic-link/request', ['email' => 'spam@x.com'])->assertNoContent();
    }
    $this->postJson('/api/v1/auth/magic-link/request', ['email' => 'spam@x.com'])->assertStatus(429);
});
