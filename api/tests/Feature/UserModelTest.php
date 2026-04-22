<?php

declare(strict_types=1);

use App\Models\User;

it('creates a user with spec fields', function () {
    $user = User::factory()->create([
        'email' => 'test@example.com',
        'name' => 'Test User',
    ])->refresh();

    expect($user->id)->toBeString();  // UUID
    expect($user->email)->toBe('test@example.com');
    expect($user->auth_provider)->toBe('email');
    expect($user->subscription_status)->toBe('free');
    expect($user->daily_goal_cards)->toBe(20);
    expect($user->reminder_enabled)->toBeFalse();
    expect($user->marketing_opt_in)->toBeFalse();
    expect((int) $user->image_quota_used_bytes)->toBe(0);
    expect($user->theme_preference)->toBe('system');
});

it('hides auth_provider_id from serialization', function () {
    $user = User::factory()->create(['auth_provider_id' => 'secret.sub.id']);
    expect($user->toArray())->not->toHaveKey('auth_provider_id');
});
