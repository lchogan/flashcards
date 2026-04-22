<?php

declare(strict_types=1);

use App\Jobs\HardDeleteExpiredUsers;
use App\Models\User;

test('DELETE /v1/me marks user for hard-delete in 30 days', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->deleteJson('/api/v1/me')
        ->assertNoContent();

    $u->refresh();
    expect($u->scheduled_delete_at)->not->toBeNull();
    $daysUntil = (int) $u->scheduled_delete_at->diffInDays(now(), absolute: true);
    expect($daysUntil)->toBeGreaterThan(28)
        ->and($daysUntil)->toBeLessThan(32);
});

test('DELETE /v1/me revokes all of the user tokens', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->deleteJson('/api/v1/me')
        ->assertNoContent();

    expect($u->fresh()->tokens()->count())->toBe(0);
});

test('DELETE /v1/me requires auth', function () {
    $this->deleteJson('/api/v1/me')->assertUnauthorized();
});

test('HardDeleteExpiredUsers purges users past their scheduled date', function () {
    $u = User::factory()->create(['scheduled_delete_at' => now()->subDays(31)]);

    (new HardDeleteExpiredUsers)->handle();

    expect(User::find($u->id))->toBeNull();
});

test('HardDeleteExpiredUsers leaves users still within the grace window alone', function () {
    $u = User::factory()->create(['scheduled_delete_at' => now()->addDays(10)]);

    (new HardDeleteExpiredUsers)->handle();

    expect(User::find($u->id))->not->toBeNull();
});

test('HardDeleteExpiredUsers leaves un-scheduled users alone', function () {
    $u = User::factory()->create(['scheduled_delete_at' => null]);

    (new HardDeleteExpiredUsers)->handle();

    expect(User::find($u->id))->not->toBeNull();
});
