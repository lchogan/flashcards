<?php

declare(strict_types=1);

use App\Models\Deck;
use App\Models\User;
use Illuminate\Support\Str;

test('push creates a deck row owned by the user', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1_713_000_000_000,
            'records' => ['decks' => [[
                'id' => $id,
                'topic_id' => null,
                'title' => 'My Deck',
                'description' => null,
                'accent_color' => 'amber',
                'default_study_mode' => 'smart',
                'card_count' => 0,
                'last_studied_at_ms' => null,
                'updated_at_ms' => 1_713_000_000_000,
                'deleted_at_ms' => null,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    expect(Deck::where('id', $id)->where('user_id', $u->id)->exists())->toBeTrue();
});

test('push rejects a stale update (older updated_at_ms than existing)', function () {
    $u = User::factory()->create();
    $deck = Deck::factory()->for($u)->create(['title' => 'Current', 'updated_at_ms' => 2000]);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1500,
            'records' => ['decks' => [[
                'id' => $deck->id,
                'topic_id' => null,
                'title' => 'Stale',
                'description' => null,
                'accent_color' => 'amber',
                'default_study_mode' => 'smart',
                'card_count' => 0,
                'last_studied_at_ms' => null,
                'updated_at_ms' => 1000,
                'deleted_at_ms' => null,
            ]]],
        ]);

    $res->assertOk()->assertJson(['accepted' => 0]);
    expect($deck->fresh()->title)->toBe('Current');
});

test('pull since=0 returns decks owned by user', function () {
    $u = User::factory()->create();
    Deck::factory()->for($u)->create(['title' => 'Alpha', 'updated_at_ms' => 100]);
    Deck::factory()->for(User::factory())->create(['title' => 'Other']); // noise

    $token = $u->createToken('t')->plainTextToken;
    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=0&entities=decks');

    $res->assertOk();
    expect($res->json('records.decks'))->toHaveCount(1)
        ->and($res->json('records.decks.0.title'))->toBe('Alpha');
});
