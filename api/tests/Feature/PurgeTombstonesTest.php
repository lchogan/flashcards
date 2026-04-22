<?php

declare(strict_types=1);

use App\Jobs\PurgeTombstones;
use App\Models\Card;
use App\Models\Deck;
use App\Models\Session;
use App\Models\SubTopic;
use App\Models\Topic;
use App\Models\User;

test('purges decks with deleted_at_ms older than 90 days', function () {
    $u = User::factory()->create();
    $old = Deck::factory()->for($u)->create([
        'deleted_at_ms' => now()->subDays(100)->getTimestampMs(),
        'updated_at_ms' => now()->getTimestampMs(),
    ]);
    $recent = Deck::factory()->for($u)->create([
        'deleted_at_ms' => now()->subDays(30)->getTimestampMs(),
        'updated_at_ms' => now()->getTimestampMs(),
    ]);
    $live = Deck::factory()->for($u)->create([
        'deleted_at_ms' => null,
        'updated_at_ms' => now()->getTimestampMs(),
    ]);

    (new PurgeTombstones)->handle();

    expect(Deck::find($old->id))->toBeNull()
        ->and(Deck::find($recent->id))->not->toBeNull()
        ->and(Deck::find($live->id))->not->toBeNull();
});

test('purges tombstones across all six tombstoned entity types', function () {
    $u = User::factory()->create();
    $old = now()->subDays(100)->getTimestampMs();

    $topic = Topic::factory()->for($u)->create(['deleted_at_ms' => $old, 'updated_at_ms' => now()->getTimestampMs()]);
    $deck = Deck::factory()->for($u)->create(['deleted_at_ms' => $old, 'updated_at_ms' => now()->getTimestampMs()]);
    $subTopic = SubTopic::factory()->for($deck)->create(['deleted_at_ms' => $old, 'updated_at_ms' => now()->getTimestampMs()]);
    $card = Card::factory()->for($deck)->create(['deleted_at_ms' => $old, 'updated_at_ms' => now()->getTimestampMs()]);
    $session = Session::factory()->create([
        'user_id' => $u->id,
        'deck_id' => $deck->id,
        'deleted_at_ms' => $old,
        'updated_at_ms' => now()->getTimestampMs(),
    ]);

    (new PurgeTombstones)->handle();

    expect(Topic::find($topic->id))->toBeNull()
        ->and(Deck::find($deck->id))->toBeNull()
        ->and(SubTopic::find($subTopic->id))->toBeNull()
        ->and(Card::find($card->id))->toBeNull()
        ->and(Session::find($session->id))->toBeNull();
});

test('preserves rows with null deleted_at_ms regardless of age', function () {
    $u = User::factory()->create();
    // Even very old rows that are alive (null deleted_at_ms) must survive.
    $liveOld = Deck::factory()->for($u)->create([
        'deleted_at_ms' => null,
        'updated_at_ms' => now()->subDays(200)->getTimestampMs(),
    ]);

    (new PurgeTombstones)->handle();

    expect(Deck::find($liveOld->id))->not->toBeNull();
});
