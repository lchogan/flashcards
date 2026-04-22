<?php

declare(strict_types=1);

use App\Models\Reminder;
use App\Models\User;

test('free user adding second reminder gets paywall', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    Reminder::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/reminders', ['time_local' => '20:00'])
        ->assertStatus(402)
        ->assertJson(['reason' => 'reminders.add']);
});

test('plus user can add three reminders', function () {
    $u = User::factory()->create(['plan_key' => 'plus']);
    $token = $u->createToken('t')->plainTextToken;

    foreach (['08:00', '13:00', '20:00'] as $t) {
        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/reminders', ['time_local' => $t])
            ->assertCreated();
    }

    expect($u->fresh()->reminders()->count())->toBe(3);
});

test('plus user gets paywall on fourth reminder', function () {
    $u = User::factory()->create(['plan_key' => 'plus']);
    Reminder::factory()->for($u)->count(3)->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/reminders', ['time_local' => '21:00'])
        ->assertStatus(402)
        ->assertJson(['reason' => 'reminders.add', 'limit' => 3]);
});

test('index returns user reminders ordered by time', function () {
    $u = User::factory()->create(['plan_key' => 'plus']);
    Reminder::factory()->for($u)->create(['time_local' => '20:00']);
    Reminder::factory()->for($u)->create(['time_local' => '08:00']);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/reminders');

    $res->assertOk();
    $times = collect($res->json('reminders'))->pluck('time_local')->all();
    expect($times[0])->toStartWith('08:00')
        ->and($times[1])->toStartWith('20:00');
});

test('user cannot modify another user reminders', function () {
    $u1 = User::factory()->create(['plan_key' => 'plus']);
    $u2 = User::factory()->create(['plan_key' => 'plus']);
    $reminder = Reminder::factory()->for($u2)->create();
    $token = $u1->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->deleteJson("/api/v1/reminders/{$reminder->id}")
        ->assertNotFound();
});

test('destroy removes the reminder', function () {
    $u = User::factory()->create(['plan_key' => 'plus']);
    $reminder = Reminder::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->deleteJson("/api/v1/reminders/{$reminder->id}")
        ->assertNoContent();

    expect(Reminder::find($reminder->id))->toBeNull();
});

test('update toggles enabled flag', function () {
    $u = User::factory()->create(['plan_key' => 'plus']);
    $reminder = Reminder::factory()->for($u)->create(['enabled' => true]);
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->patchJson("/api/v1/reminders/{$reminder->id}", ['enabled' => false])
        ->assertOk();

    expect($reminder->fresh()->enabled)->toBeFalse();
});
