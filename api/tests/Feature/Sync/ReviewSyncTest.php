<?php

declare(strict_types=1);

use App\Models\Card;
use App\Models\Deck;
use App\Models\Review;
use App\Models\User;
use Illuminate\Support\Str;

test('review push creates a review row', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->for($d)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['reviews' => [[
                'id' => $id, 'card_id' => $card->id, 'user_id' => $u->id,
                'rating' => 3, 'review_duration_ms' => 2500, 'rated_at_ms' => 1000,
                'state_before' => ['state' => 'new'],
                'state_after' => ['state' => 'learning', 'stability' => 1.0, 'difficulty' => 5.0],
                'scheduler_version' => 'fsrs-6', 'updated_at_ms' => 1000,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    expect(Review::where('id', $id)->exists())->toBeTrue();
});

test('duplicate review id is idempotent (insert-once semantics)', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->for($d)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) Str::orderedUuid();
    $payload = [[
        'id' => $id, 'card_id' => $card->id, 'user_id' => $u->id,
        'rating' => 3, 'rated_at_ms' => 1000,
        'state_before' => [], 'state_after' => [],
        'updated_at_ms' => 1000,
    ]];

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', ['client_clock_ms' => 1000, 'records' => ['reviews' => $payload]])
        ->assertOk()->assertJson(['accepted' => 1]);
    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', ['client_clock_ms' => 1000, 'records' => ['reviews' => $payload]])
        ->assertOk()->assertJson(['accepted' => 0]);

    expect(Review::count())->toBe(1);
});

test('review pull does not leak other users reviews', function () {
    $owner = User::factory()->create();
    $intruder = User::factory()->create();
    $ownerDeck = Deck::factory()->for($owner)->create();
    $intruderDeck = Deck::factory()->for($intruder)->create();
    $ownerCard = Card::factory()->for($ownerDeck)->create();
    $intruderCard = Card::factory()->for($intruderDeck)->create();

    Review::factory()->create([
        'card_id' => $ownerCard->id, 'user_id' => $owner->id,
        'rated_at_ms' => 1000, 'updated_at_ms' => 1000,
    ]);
    Review::factory()->create([
        'card_id' => $intruderCard->id, 'user_id' => $intruder->id,
        'rated_at_ms' => 1000, 'updated_at_ms' => 1000,
    ]);

    $token = $owner->createToken('t')->plainTextToken;
    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=0&entities=reviews');

    $res->assertOk();
    expect($res->json('records.reviews'))->toHaveCount(1)
        ->and($res->json('records.reviews.0.user_id'))->toBe($owner->id);
});
