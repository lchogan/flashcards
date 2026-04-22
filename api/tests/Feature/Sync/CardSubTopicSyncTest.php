<?php

declare(strict_types=1);

use App\Models\Card;
use App\Models\CardSubTopic;
use App\Models\Deck;
use App\Models\SubTopic;
use App\Models\User;
use Illuminate\Support\Str;

test('push creates card-subtopic association', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->for($d)->create();
    $st = SubTopic::factory()->for($d)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['card_sub_topics' => [[
                'id' => $id,
                'card_id' => $card->id, 'sub_topic_id' => $st->id,
                'updated_at_ms' => 1000,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    expect(CardSubTopic::where('card_id', $card->id)->where('sub_topic_id', $st->id)->exists())->toBeTrue();
});

test('push rejects association when card and sub-topic belong to different decks', function () {
    $u = User::factory()->create();
    $d1 = Deck::factory()->for($u)->create();
    $d2 = Deck::factory()->for($u)->create();
    $card = Card::factory()->for($d1)->create();
    $st = SubTopic::factory()->for($d2)->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['card_sub_topics' => [[
                'id' => (string) Str::orderedUuid(),
                'card_id' => $card->id, 'sub_topic_id' => $st->id,
                'updated_at_ms' => 1000,
            ]]],
        ])->assertJson(['accepted' => 0]);
});

test('push rejects association when attacker does not own card', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $d = Deck::factory()->for($owner)->create();
    $card = Card::factory()->for($d)->create();
    $st = SubTopic::factory()->for($d)->create();
    $token = $attacker->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['card_sub_topics' => [[
                'id' => (string) Str::orderedUuid(),
                'card_id' => $card->id, 'sub_topic_id' => $st->id,
                'updated_at_ms' => 1000,
            ]]],
        ])->assertJson(['accepted' => 0]);
});

test('pull does not leak associations belonging to other users', function () {
    $owner = User::factory()->create();
    $intruder = User::factory()->create();
    $ownerDeck = Deck::factory()->for($owner)->create();
    $intruderDeck = Deck::factory()->for($intruder)->create();
    $ownerCard = Card::factory()->for($ownerDeck)->create();
    $ownerSt = SubTopic::factory()->for($ownerDeck)->create();
    $intruderCard = Card::factory()->for($intruderDeck)->create();
    $intruderSt = SubTopic::factory()->for($intruderDeck)->create();

    CardSubTopic::factory()->create([
        'card_id' => $ownerCard->id, 'sub_topic_id' => $ownerSt->id,
        'updated_at_ms' => 1000,
    ]);
    CardSubTopic::factory()->create([
        'card_id' => $intruderCard->id, 'sub_topic_id' => $intruderSt->id,
        'updated_at_ms' => 1000,
    ]);

    $token = $owner->createToken('t')->plainTextToken;
    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=0&entities=card_sub_topics');

    $res->assertOk();
    expect($res->json('records.card_sub_topics'))->toHaveCount(1)
        ->and($res->json('records.card_sub_topics.0.card_id'))->toBe($ownerCard->id);
});
