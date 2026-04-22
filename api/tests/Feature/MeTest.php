<?php

declare(strict_types=1);

use App\Models\User;

test('GET /v1/me returns authed user shape', function () {
    $u = User::factory()->create(['name' => 'Alice']);
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")->getJson('/api/v1/me')
        ->assertOk()
        ->assertJsonStructure(['id', 'email', 'name', 'daily_goal_cards', 'theme_preference', 'subscription_status']);
});

test('PATCH /v1/me updates profile fields', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->patchJson('/api/v1/me', ['daily_goal_cards' => 50, 'theme_preference' => 'dark'])
        ->assertOk();

    expect($u->fresh()->daily_goal_cards)->toBe(50)
        ->and($u->fresh()->theme_preference)->toBe('dark');
});

test('GET /v1/me without auth returns 401', function () {
    $this->getJson('/api/v1/me')->assertUnauthorized();
});

test('PATCH /v1/me validates daily_goal_cards bounds', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->patchJson('/api/v1/me', ['daily_goal_cards' => 999])
        ->assertStatus(422);
});
