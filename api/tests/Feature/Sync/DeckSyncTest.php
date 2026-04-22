<?php

declare(strict_types=1);

use App\Models\Deck;
use App\Models\Topic;
use App\Models\User;
use Illuminate\Support\Str;

test('push creates deck and persists all spec fields', function () {
    $u = User::factory()->create();
    $topic = Topic::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['decks' => [[
                'id' => $id,
                'topic_id' => $topic->id,
                'title' => 'Spanish 1',
                'description' => 'Verbs',
                'accent_color' => 'moss',
                'default_study_mode' => 'smart',
                'card_count' => 0,
                'last_studied_at_ms' => null,
                'updated_at_ms' => 1000,
                'deleted_at_ms' => null,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    $d = Deck::findOrFail($id);
    expect($d->user_id)->toBe($u->id)
        ->and($d->topic_id)->toBe($topic->id)
        ->and($d->title)->toBe('Spanish 1')
        ->and($d->accent_color)->toBe('moss');
});

test('tombstone push marks deck deleted', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create(['updated_at_ms' => 1000]);
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 2000,
            'records' => ['decks' => [[
                'id' => $d->id,
                'title' => $d->title,
                'accent_color' => $d->accent_color,
                'default_study_mode' => 'smart',
                'card_count' => 0,
                'updated_at_ms' => 2000,
                'deleted_at_ms' => 2000,
            ]]],
        ])->assertJson(['accepted' => 1]);

    expect($d->fresh()->deleted_at_ms)->toBe(2000);
});

test('pull returns decks since cursor', function () {
    $u = User::factory()->create();
    Deck::factory()->for($u)->create(['title' => 'Old', 'updated_at_ms' => 100]);
    Deck::factory()->for($u)->create(['title' => 'New', 'updated_at_ms' => 200]);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=150&entities=decks');

    expect($res->json('records.decks'))->toHaveCount(1)
        ->and($res->json('records.decks.0.title'))->toBe('New');
});
