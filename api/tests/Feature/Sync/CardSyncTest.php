<?php

declare(strict_types=1);

use App\Models\Card;
use App\Models\Deck;
use App\Models\User;
use Illuminate\Support\Str;

test('card push creates row in user\'s deck', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['cards' => [[
                'id' => $id, 'deck_id' => $d->id,
                'front_text' => 'hola', 'back_text' => 'hi',
                'position' => 0, 'state' => 'new',
                'reps' => 0, 'lapses' => 0,
                'updated_at_ms' => 1000,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    expect(Card::find($id)?->deck_id)->toBe($d->id);
});

test('card push to non-owned deck rejected', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $d = Deck::factory()->for($owner)->create();
    $token = $attacker->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['cards' => [[
                'id' => (string) Str::orderedUuid(),
                'deck_id' => $d->id, 'front_text' => 'x', 'back_text' => 'x',
                'state' => 'new', 'updated_at_ms' => 1000,
            ]]],
        ])->assertJson(['accepted' => 0]);
});

test('card pull does not leak cards belonging to other users', function () {
    $owner = User::factory()->create();
    $intruder = User::factory()->create();
    $ownerDeck = Deck::factory()->for($owner)->create();
    $intruderDeck = Deck::factory()->for($intruder)->create();

    Card::factory()->for($ownerDeck)->create(['front_text' => 'Mine', 'updated_at_ms' => 1000]);
    Card::factory()->for($intruderDeck)->create(['front_text' => 'Not yours', 'updated_at_ms' => 1000]);

    $token = $owner->createToken('t')->plainTextToken;
    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=0&entities=cards');

    $res->assertOk();
    expect($res->json('records.cards'))->toHaveCount(1)
        ->and($res->json('records.cards.0.front_text'))->toBe('Mine');
});

test('card push rejects stale update older than existing', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $c = Card::factory()->for($d)->create([
        'front_text' => 'Current',
        'updated_at_ms' => 2000,
    ]);
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1500,
            'records' => ['cards' => [[
                'id' => $c->id, 'deck_id' => $d->id,
                'front_text' => 'Stale',
                'back_text' => $c->back_text,
                'state' => 'new',
                'updated_at_ms' => 1000,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 0]);

    expect($c->fresh()->front_text)->toBe('Current');
});
