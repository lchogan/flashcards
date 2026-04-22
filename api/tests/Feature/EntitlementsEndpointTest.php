<?php

declare(strict_types=1);

use App\Models\User;
use Database\Seeders\PlanSeeder;

beforeEach(function () {
    $this->seed(PlanSeeder::class);
});

test('GET /v1/me/entitlements returns current plan + snapshot', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/me/entitlements');

    $res->assertOk()->assertJsonStructure(['plan_key', 'entitlements', 'version']);

    $entitlements = $res->json('entitlements');
    expect($res->json('plan_key'))->toBe('free')
        ->and($entitlements['decks.create']['max'])->toBe(5)
        ->and($entitlements['study.smart']['allowed'])->toBeTrue();
});

test('GET /v1/me/entitlements returns plus plan for plus users', function () {
    $u = User::factory()->create(['plan_key' => 'plus']);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/me/entitlements');

    $res->assertOk();

    $entitlements = $res->json('entitlements');
    expect($res->json('plan_key'))->toBe('plus')
        ->and($entitlements['decks.create']['max'])->toBeNull()
        ->and($entitlements['new_card_limit.above_10']['allowed'])->toBeTrue();
});

test('GET /v1/me/entitlements requires authentication', function () {
    $res = $this->getJson('/api/v1/me/entitlements');
    $res->assertUnauthorized();
});
