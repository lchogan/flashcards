<?php

declare(strict_types=1);

use App\Models\User;

test('GET /v1/sync/pull returns empty record map when nothing exists', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=0&entities=decks,topics');

    $res->assertOk()->assertJsonStructure(['server_clock_ms', 'records', 'has_more']);
    expect($res->json('records.decks'))->toBe([])
        ->and($res->json('has_more'))->toBeFalse();
});
