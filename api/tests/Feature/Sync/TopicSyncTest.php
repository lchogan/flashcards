<?php

declare(strict_types=1);

use App\Models\Topic;
use App\Models\User;
use Illuminate\Support\Str;

test('push creates a topic row owned by the user', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1_713_000_000_000,
            'records' => ['topics' => [[
                'id' => $id, 'name' => 'Biology', 'color_hint' => null,
                'updated_at_ms' => 1_713_000_000_000, 'deleted_at_ms' => null,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    expect(Topic::where('id', $id)->where('user_id', $u->id)->exists())->toBeTrue();
});

test('push rejects a stale update (older updated_at_ms than existing)', function () {
    $u = User::factory()->create();
    $t = Topic::factory()->for($u)->create(['name' => 'Current', 'updated_at_ms' => 2000]);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1500,
            'records' => ['topics' => [[
                'id' => $t->id, 'name' => 'Stale', 'color_hint' => null,
                'updated_at_ms' => 1000, 'deleted_at_ms' => null,
            ]]],
        ]);

    $res->assertOk()->assertJson(['accepted' => 0]);
    expect($t->fresh()->name)->toBe('Current');
});

test('partial push preserves omitted color_hint', function () {
    // A topic with an existing color_hint value.
    $u = User::factory()->create();
    $t = Topic::factory()->for($u)->create([
        'name' => 'Biology',
        'color_hint' => 'green',
        'updated_at_ms' => 1000,
    ]);
    $token = $u->createToken('t')->plainTextToken;

    // Push an update that omits color_hint entirely.
    // The existing 'green' value must be preserved — an absent key must not overwrite with null.
    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 2000,
            'records' => ['topics' => [[
                'id' => $t->id,
                'name' => 'Biology (renamed)',
                'updated_at_ms' => 2000,
                // color_hint intentionally omitted
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    $fresh = $t->fresh();
    expect($fresh->name)->toBe('Biology (renamed)')
        ->and($fresh->color_hint)->toBe('green');
});

test('pull since=0 returns topics owned by user', function () {
    $u = User::factory()->create();
    Topic::factory()->for($u)->create(['name' => 'Alpha', 'updated_at_ms' => 100]);
    Topic::factory()->for(User::factory())->create(['name' => 'Other']); // noise

    $token = $u->createToken('t')->plainTextToken;
    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=0&entities=topics');

    $res->assertOk();
    expect($res->json('records.topics'))->toHaveCount(1)
        ->and($res->json('records.topics.0.name'))->toBe('Alpha');
});
