<?php

declare(strict_types=1);

use App\Models\Card;
use App\Models\Deck;
use App\Models\User;
use Illuminate\Support\Str;

beforeEach(function () {
    $this->seed(\Database\Seeders\PlanSeeder::class);
});

test('free user pushing 6th deck: sixth rejected with reason=decks.create', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    Deck::factory()->for($u)->count(5)->create(['updated_at_ms' => 1000]);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 2000,
            'records' => ['decks' => [[
                'id' => (string) Str::orderedUuid(),
                'title' => '6th',
                'accent_color' => 'amber',
                'default_study_mode' => 'smart',
                'card_count' => 0,
                'updated_at_ms' => 2000,
            ]]],
        ]);

    $res->assertOk()->assertJson(['accepted' => 0]);
    expect($res->json('rejected.0.reason'))->toBe('decks.create');
});

test('free user editing an existing deck is not gated', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    $decks = Deck::factory()->for($u)->count(5)->create(['updated_at_ms' => 1000]);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 3000,
            'records' => ['decks' => [[
                'id' => $decks->first()->id,
                'title' => 'Renamed',
                'accent_color' => 'amber',
                'default_study_mode' => 'smart',
                'card_count' => 0,
                'updated_at_ms' => 3000,
            ]]],
        ]);

    $res->assertOk()->assertJson(['accepted' => 1]);
});

test('plus user can push more than 5 decks', function () {
    $u = User::factory()->create(['plan_key' => 'plus']);
    Deck::factory()->for($u)->count(5)->create(['updated_at_ms' => 1000]);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 2000,
            'records' => ['decks' => [[
                'id' => (string) Str::orderedUuid(),
                'title' => '6th',
                'accent_color' => 'amber',
                'default_study_mode' => 'smart',
                'card_count' => 0,
                'updated_at_ms' => 2000,
            ]]],
        ]);

    $res->assertOk()->assertJson(['accepted' => 1]);
});

test('free user pushing 201st card in a deck: rejected with reason=cards.create_in_deck', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    $deck = Deck::factory()->for($u)->create(['updated_at_ms' => 1000]);
    Card::factory()->count(200)->create([
        'deck_id' => $deck->id,
        'updated_at_ms' => 1000,
    ]);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 2000,
            'records' => ['cards' => [[
                'id' => (string) Str::orderedUuid(),
                'deck_id' => $deck->id,
                'front_text' => 'F',
                'back_text' => 'B',
                'position' => 201,
                'updated_at_ms' => 2000,
            ]]],
        ]);

    $res->assertOk()->assertJson(['accepted' => 0]);
    expect($res->json('rejected.0.reason'))->toBe('cards.create_in_deck');
});
