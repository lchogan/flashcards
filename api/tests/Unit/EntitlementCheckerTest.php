<?php

declare(strict_types=1);

use App\Models\Deck;
use App\Models\User;
use App\Services\Entitlements\EntitlementChecker;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->seed(\Database\Seeders\PlanSeeder::class);
});

test('free user hitting 5-deck cap on create returns paywall', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    Deck::factory()->for($u)->count(5)->create();

    $result = app(EntitlementChecker::class)->can($u, 'decks.create');

    expect($result->allowed)->toBeFalse()
        ->and($result->reason)->toBe('decks.create')
        ->and($result->limit)->toBe(5);
});

test('free user with 3 decks can create another', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    Deck::factory()->for($u)->count(3)->create();

    expect(app(EntitlementChecker::class)->can($u, 'decks.create')->allowed)->toBeTrue();
});

test('plus user has no deck cap', function () {
    $u = User::factory()->create(['plan_key' => 'plus']);
    Deck::factory()->for($u)->count(100)->create();

    expect(app(EntitlementChecker::class)->can($u, 'decks.create')->allowed)->toBeTrue();
});

test('boolean entitlement study.smart returns allowed per plan', function () {
    $free = User::factory()->create(['plan_key' => 'free']);
    expect(app(EntitlementChecker::class)->can($free, 'study.smart')->allowed)->toBeTrue();
});

test('boolean entitlement images.use is denied on free', function () {
    $free = User::factory()->create(['plan_key' => 'free']);
    $result = app(EntitlementChecker::class)->can($free, 'images.use');

    expect($result->allowed)->toBeFalse()
        ->and($result->reason)->toBe('images.use');
});

test('unknown entitlement keys deny by default', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    $result = app(EntitlementChecker::class)->can($u, 'nope.unknown');

    expect($result->allowed)->toBeFalse();
});

test('soft-deleted decks do not count toward the deck cap', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    Deck::factory()->for($u)->count(4)->create();
    Deck::factory()->for($u)->create(['deleted_at_ms' => now()->getTimestampMs()]);

    expect(app(EntitlementChecker::class)->can($u, 'decks.create')->allowed)->toBeTrue();
});

test('null plan_key falls back to free plan', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    Deck::factory()->for($u)->count(5)->create();

    expect(app(EntitlementChecker::class)->can($u, 'decks.create')->allowed)->toBeFalse();
});
