<?php

declare(strict_types=1);

use App\Models\User;

test('POST /v1/sync/push with empty records returns accepted=0', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', ['client_clock_ms' => 0, 'records' => (object) []]);

    $res->assertOk()->assertJsonStructure(['accepted', 'rejected', 'server_clock_ms']);
    expect($res->json('accepted'))->toBe(0);
});

test('unauthenticated push returns 401', function () {
    $this->postJson('/api/v1/sync/push', ['client_clock_ms' => 0, 'records' => (object) []])
        ->assertStatus(401);
});
