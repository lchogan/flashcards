<?php

declare(strict_types=1);

/**
 * AppleAuthTest — feature coverage for POST /api/v1/auth/apple.
 *
 * Purpose:
 *   Exercise the Apple Sign In endpoint end-to-end: first-time sign-in
 *   provisions a User, subsequent sign-ins reuse it, and both return access
 *   + refresh tokens. The AppleIdentityVerifier is mocked via the container
 *   so tests don't touch the network or real Apple keys.
 *
 * Key concepts:
 *   - Pest's Feature suite already wires Illuminate\Foundation\Testing\RefreshDatabase
 *     globally (see tests/Pest.php), so the `users` table is reset per test.
 *   - `$this->mock(...)` registers a Mockery instance under the verifier class
 *     in the container; the controller resolves it there and uses the mock.
 */

use App\Models\User;
use App\Services\Auth\AppleClaims;
use App\Services\Auth\AppleIdentityVerifier;

test('POST /v1/auth/apple creates user on first sign-in and returns tokens', function () {
    $this->mock(AppleIdentityVerifier::class, function ($mock) {
        $mock->shouldReceive('verify')
            ->once()
            ->andReturn(new AppleClaims(subject: 'APPLE_UID_1', email: 'a@b.com'));
    });

    $response = $this->postJson('/api/v1/auth/apple', [
        'identity_token' => 'stub.jwt.token',
    ]);

    $response->assertOk()
        ->assertJsonStructure(['access_token', 'refresh_token', 'user' => ['id', 'email']]);

    expect(User::where('email', 'a@b.com')->exists())->toBeTrue();
});

test('POST /v1/auth/apple returns same user on subsequent sign-in', function () {
    $u = User::factory()->create([
        'auth_provider' => 'apple',
        'auth_provider_id' => 'APPLE_UID_2',
        'email' => 'c@d.com',
    ]);

    $this->mock(AppleIdentityVerifier::class, function ($mock) {
        $mock->shouldReceive('verify')
            ->andReturn(new AppleClaims(subject: 'APPLE_UID_2', email: 'c@d.com'));
    });

    $response = $this->postJson('/api/v1/auth/apple', ['identity_token' => 'x']);

    $response->assertOk();
    expect($response->json('user.id'))->toBe($u->id);
});
