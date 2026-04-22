<?php

declare(strict_types=1);

/**
 * MagicLinkConsumeTest — feature coverage for POST /api/v1/auth/magic-link/consume.
 *
 * Purpose:
 *   Verify the consume endpoint exchanges a valid one-time token for an
 *   access/refresh token pair, creates (or finds) the email-auth User, and
 *   rejects invalid, expired, or already-consumed tokens with HTTP 410.
 *
 * Key concepts:
 *   - Pest Feature suite auto-applies RefreshDatabase (see tests/Pest.php),
 *     so `pending_email_auths` and `users` start empty per test.
 *   - Tokens are hashed with sha256 before storage; tests mint a token,
 *     persist its hash, then POST the plaintext — mirroring production flow.
 *   - Second-use rejection relies on the `consumed_at` marker set by the
 *     controller on successful exchange.
 */

use App\Models\PendingEmailAuth;
use App\Models\User;

test('valid token consumes and returns access/refresh + user', function () {
    $token = bin2hex(random_bytes(32));
    PendingEmailAuth::create([
        'email' => 'm@l.com',
        'token_hash' => hash('sha256', $token),
        'expires_at' => now()->addMinutes(10),
    ]);

    $res = $this->postJson('/api/v1/auth/magic-link/consume', ['token' => $token]);

    $res->assertOk()->assertJsonStructure(['access_token', 'refresh_token', 'user' => ['id', 'email']]);
    expect(User::where('email', 'm@l.com')->exists())->toBeTrue();
});

test('expired token returns 410', function () {
    $token = bin2hex(random_bytes(32));
    PendingEmailAuth::create([
        'email' => 'e@x.com',
        'token_hash' => hash('sha256', $token),
        'expires_at' => now()->subMinutes(1),
    ]);
    $this->postJson('/api/v1/auth/magic-link/consume', ['token' => $token])->assertStatus(410);
});

test('consumed token returns 410 on second use', function () {
    $token = bin2hex(random_bytes(32));
    PendingEmailAuth::create([
        'email' => 'c@x.com',
        'token_hash' => hash('sha256', $token),
        'expires_at' => now()->addMinutes(10),
    ]);
    $this->postJson('/api/v1/auth/magic-link/consume', ['token' => $token])->assertOk();
    $this->postJson('/api/v1/auth/magic-link/consume', ['token' => $token])->assertStatus(410);
});
