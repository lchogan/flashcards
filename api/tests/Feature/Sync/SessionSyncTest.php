<?php

declare(strict_types=1);

use App\Models\Deck;
use App\Models\Session;
use App\Models\User;
use Illuminate\Support\Str;

test('session push creates row for user deck', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['sessions' => [[
                'id' => $id, 'user_id' => $u->id, 'deck_id' => $d->id,
                'mode' => 'smart', 'started_at_ms' => 1000, 'cards_reviewed' => 10,
                'accuracy_pct' => 80.0, 'mastery_delta' => 5.0, 'updated_at_ms' => 1000,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    expect(Session::find($id))->not->toBeNull()
        ->and(Session::find($id)->mode)->toBe('smart')
        ->and(Session::find($id)->cards_reviewed)->toBe(10);
});

test('session push against non-owned deck rejected', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $d = Deck::factory()->for($owner)->create();
    $token = $attacker->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['sessions' => [[
                'id' => (string) Str::orderedUuid(),
                'user_id' => $attacker->id, 'deck_id' => $d->id,
                'mode' => 'smart', 'started_at_ms' => 1000, 'updated_at_ms' => 1000,
            ]]],
        ])->assertJson(['accepted' => 0]);
});

test('session pull returns only owner sessions', function () {
    $owner = User::factory()->create();
    $other = User::factory()->create();
    $ownerDeck = Deck::factory()->for($owner)->create();
    $otherDeck = Deck::factory()->for($other)->create();

    Session::factory()->create([
        'user_id' => $owner->id, 'deck_id' => $ownerDeck->id,
        'mode' => 'smart', 'updated_at_ms' => 1000,
    ]);
    Session::factory()->create([
        'user_id' => $other->id, 'deck_id' => $otherDeck->id,
        'mode' => 'smart', 'updated_at_ms' => 1000,
    ]);

    $token = $owner->createToken('t')->plainTextToken;
    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=0&entities=sessions');

    $res->assertOk();
    expect($res->json('records.sessions'))->toHaveCount(1)
        ->and($res->json('records.sessions.0.user_id'))->toBe($owner->id);
});
