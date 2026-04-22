<?php

declare(strict_types=1);

use App\Models\User;

test('authed user is throttled after 60 requests in a minute', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    for ($i = 0; $i < 60; $i++) {
        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/v1/me')
            ->assertOk();
    }

    $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/me')
        ->assertStatus(429);
});

test('the 429 response carries rate-limit headers', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    for ($i = 0; $i < 60; $i++) {
        $this->withHeader('Authorization', "Bearer {$token}")->getJson('/api/v1/me');
    }

    $res = $this->withHeader('Authorization', "Bearer {$token}")->getJson('/api/v1/me');
    $res->assertStatus(429);
    expect($res->headers->get('X-RateLimit-Limit'))->toBe('60')
        ->and($res->headers->get('Retry-After'))->not->toBeNull();
});
