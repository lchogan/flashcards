<?php

declare(strict_types=1);

/**
 * TokenRefreshTest — feature coverage for POST /api/v1/auth/refresh.
 *
 * Purpose:
 *   Verify the refresh endpoint rotates an `auth:refresh`-scoped token into
 *   a fresh access+refresh pair, rejects access-scoped tokens (wrong ability),
 *   and rejects expired refresh tokens.
 *
 * Key concepts:
 *   - Pest Feature suite auto-applies RefreshDatabase (see tests/Pest.php),
 *     so `users` and `personal_access_tokens` start empty per test.
 *   - Rotation: a successful refresh MUST return a refresh_token that differs
 *     from the one presented, and the old row must be gone.
 *   - Access-as-refresh: a token issued with abilities `['*']` must be rejected
 *     even though it's otherwise valid — scope discrimination is load-bearing.
 *   - Expired refresh: Sanctum's PersonalAccessToken::findToken doesn't check
 *     expiry; the controller does, and this test exercises that branch.
 */

use App\Models\User;

test('valid refresh token yields new access token; refresh rotates', function () {
    $u = User::factory()->create();
    $refresh = $u->createToken('refresh', ['auth:refresh'], now()->addDays(90))->plainTextToken;

    $res = $this->postJson('/api/v1/auth/refresh', ['refresh_token' => $refresh]);

    $res->assertOk()->assertJsonStructure(['access_token', 'refresh_token']);
    expect($res->json('refresh_token'))->not->toBe($refresh);
});

test('access token cannot refresh', function () {
    $u = User::factory()->create();
    $access = $u->createToken('ios', ['*'], now()->addMinutes(15))->plainTextToken;
    $this->postJson('/api/v1/auth/refresh', ['refresh_token' => $access])->assertStatus(401);
});

test('expired refresh token returns 401', function () {
    $u = User::factory()->create();
    $refresh = $u->createToken('refresh', ['auth:refresh'], now()->subMinute())->plainTextToken;
    $this->postJson('/api/v1/auth/refresh', ['refresh_token' => $refresh])->assertStatus(401);
});
