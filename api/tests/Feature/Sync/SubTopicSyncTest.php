<?php

declare(strict_types=1);

use App\Models\Deck;
use App\Models\SubTopic;
use App\Models\User;
use Illuminate\Support\Str;

test('push creates sub-topic under a deck owned by user', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['sub_topics' => [[
                'id' => $id, 'deck_id' => $d->id, 'name' => 'Verbs', 'position' => 1,
                'updated_at_ms' => 1000, 'deleted_at_ms' => null,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    expect(SubTopic::find($id)?->deck_id)->toBe($d->id);
});

test('push rejects sub-topic attaching to someone else\'s deck', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $d = Deck::factory()->for($owner)->create();
    $token = $attacker->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['sub_topics' => [[
                'id' => (string) Str::orderedUuid(),
                'deck_id' => $d->id, 'name' => 'Evil', 'position' => 0,
                'updated_at_ms' => 1000,
            ]]],
        ]);
    $res->assertJson(['accepted' => 0]);
});

test('pull does not leak sub-topics belonging to other users', function () {
    $owner = User::factory()->create();
    $intruder = User::factory()->create();

    $ownerDeck = Deck::factory()->for($owner)->create();
    $intruderDeck = Deck::factory()->for($intruder)->create();

    SubTopic::factory()->for($ownerDeck)->create(['name' => 'Mine', 'updated_at_ms' => 1000]);
    SubTopic::factory()->for($intruderDeck)->create(['name' => 'Not yours', 'updated_at_ms' => 1000]);

    $token = $owner->createToken('t')->plainTextToken;
    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=0&entities=sub_topics');

    $res->assertOk();
    expect($res->json('records.sub_topics'))->toHaveCount(1)
        ->and($res->json('records.sub_topics.0.name'))->toBe('Mine');
});
