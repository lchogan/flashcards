<?php

declare(strict_types=1);

use App\Models\User;

test('POST /v1/subscriptions/verify flips user to plus', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    $token = $u->createToken('t')->plainTextToken;

    $payload = base64_encode((string) json_encode([
        'productId' => 'com.lukehogan.flashcards.plus.annual',
        'originalTransactionId' => 'TX123',
        'expiresDate' => now()->addYear()->valueOf(),
        'environment' => 'Sandbox',
    ]));

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/subscriptions/verify', ['jws' => $payload])
        ->assertOk()
        ->assertJson(['plan_key' => 'plus']);

    $fresh = $u->fresh();
    expect($fresh->plan_key)->toBe('plus')
        ->and($fresh->subscription_status)->toBe('active')
        ->and($fresh->subscription_original_transaction_id)->toBe('TX123')
        ->and($fresh->subscription_product_id)->toBe('com.lukehogan.flashcards.plus.annual');
});

test('POST /v1/subscriptions/verify accepts StoreKit JWS representation', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    $token = $u->createToken('t')->plainTextToken;

    $header = rtrim(strtr(base64_encode((string) json_encode(['alg' => 'ES256'])), '+/', '-_'), '=');
    $payload = rtrim(strtr(base64_encode((string) json_encode([
        'productId' => 'com.lukehogan.flashcards.plus.monthly',
        'originalTransactionId' => 'TX999',
        'expiresDate' => now()->addMonth()->valueOf(),
        'environment' => 'Sandbox',
    ])), '+/', '-_'), '=');
    $jws = "{$header}.{$payload}.stub-signature";

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/subscriptions/verify', ['jws' => $jws])
        ->assertOk()
        ->assertJson(['plan_key' => 'plus']);

    expect($u->fresh()->subscription_original_transaction_id)->toBe('TX999');
});

test('POST /v1/subscriptions/verify rejects malformed payloads', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/subscriptions/verify', ['jws' => 'not-base64-$$$'])
        ->assertStatus(422);

    expect($u->fresh()->plan_key)->toBe('free');
});

test('POST /v1/subscriptions/verify requires auth', function () {
    $payload = base64_encode((string) json_encode([
        'productId' => 'com.lukehogan.flashcards.plus.annual',
        'originalTransactionId' => 'TX1',
        'expiresDate' => 0,
    ]));

    $this->postJson('/api/v1/subscriptions/verify', ['jws' => $payload])
        ->assertUnauthorized();
});

test('App Store webhook DID_RENEW keeps user on plus', function () {
    $u = User::factory()->create([
        'plan_key' => 'plus',
        'subscription_status' => 'in_grace',
        'subscription_original_transaction_id' => 'TXRENEW',
    ]);

    $signedTx = base64_encode((string) json_encode([
        'productId' => 'com.lukehogan.flashcards.plus.annual',
        'originalTransactionId' => 'TXRENEW',
        'expiresDate' => now()->addYear()->valueOf(),
    ]));
    $signedPayload = base64_encode((string) json_encode([
        'notificationType' => 'DID_RENEW',
        'data' => ['signedTransactionInfo' => $signedTx],
    ]));

    $this->postJson('/api/v1/webhooks/app-store', ['signedPayload' => $signedPayload])
        ->assertOk();

    expect($u->fresh()->subscription_status)->toBe('active')
        ->and($u->fresh()->plan_key)->toBe('plus');
});

test('App Store webhook EXPIRED moves user back to free', function () {
    $u = User::factory()->create([
        'plan_key' => 'plus',
        'subscription_status' => 'active',
        'subscription_original_transaction_id' => 'TXEXP',
    ]);

    $signedTx = base64_encode((string) json_encode([
        'productId' => 'com.lukehogan.flashcards.plus.annual',
        'originalTransactionId' => 'TXEXP',
        'expiresDate' => now()->subDay()->valueOf(),
    ]));
    $signedPayload = base64_encode((string) json_encode([
        'notificationType' => 'EXPIRED',
        'data' => ['signedTransactionInfo' => $signedTx],
    ]));

    $this->postJson('/api/v1/webhooks/app-store', ['signedPayload' => $signedPayload])
        ->assertOk();

    expect($u->fresh()->plan_key)->toBe('free')
        ->and($u->fresh()->subscription_status)->toBe('expired');
});

test('App Store webhook REFUND revokes Plus', function () {
    $u = User::factory()->create([
        'plan_key' => 'plus',
        'subscription_status' => 'active',
        'subscription_original_transaction_id' => 'TXREFUND',
    ]);

    $signedTx = base64_encode((string) json_encode([
        'productId' => 'com.lukehogan.flashcards.plus.annual',
        'originalTransactionId' => 'TXREFUND',
        'expiresDate' => now()->addYear()->valueOf(),
    ]));
    $signedPayload = base64_encode((string) json_encode([
        'notificationType' => 'REFUND',
        'data' => ['signedTransactionInfo' => $signedTx],
    ]));

    $this->postJson('/api/v1/webhooks/app-store', ['signedPayload' => $signedPayload])
        ->assertOk();

    expect($u->fresh()->plan_key)->toBe('free');
});

test('App Store webhook for unknown originalTransactionId is a safe no-op', function () {
    $signedTx = base64_encode((string) json_encode([
        'productId' => 'com.lukehogan.flashcards.plus.annual',
        'originalTransactionId' => 'TX-NOBODY',
        'expiresDate' => now()->addYear()->valueOf(),
    ]));
    $signedPayload = base64_encode((string) json_encode([
        'notificationType' => 'DID_RENEW',
        'data' => ['signedTransactionInfo' => $signedTx],
    ]));

    $this->postJson('/api/v1/webhooks/app-store', ['signedPayload' => $signedPayload])
        ->assertOk();
});
