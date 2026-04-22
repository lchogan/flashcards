<?php

declare(strict_types=1);

use App\Models\User;
use App\Notifications\PaymentFailed;
use App\Notifications\SubscriptionRenewed;
use Illuminate\Support\Facades\Notification;

test('POST /v1/me/device-token stores the APNs token', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/me/device-token', ['device_token' => 'DEVICE-TOKEN-HEX'])
        ->assertNoContent();

    expect($u->fresh()->apn_device_token)->toBe('DEVICE-TOKEN-HEX');
});

test('POST /v1/me/device-token requires auth', function () {
    $this->postJson('/api/v1/me/device-token', ['device_token' => 'X'])
        ->assertUnauthorized();
});

test('DID_RENEW webhook triggers SubscriptionRenewed notification', function () {
    Notification::fake();

    $u = User::factory()->create([
        'plan_key' => 'plus',
        'subscription_status' => 'in_grace',
        'subscription_original_transaction_id' => 'TXR',
        'apn_device_token' => 'HEXTOKEN',
    ]);

    $signedTx = base64_encode((string) json_encode([
        'productId' => 'com.lukehogan.flashcards.plus.annual',
        'originalTransactionId' => 'TXR',
        'expiresDate' => now()->addYear()->valueOf(),
    ]));
    $signedPayload = base64_encode((string) json_encode([
        'notificationType' => 'DID_RENEW',
        'data' => ['signedTransactionInfo' => $signedTx],
    ]));

    $this->postJson('/api/v1/webhooks/app-store', ['signedPayload' => $signedPayload])->assertOk();

    Notification::assertSentTo($u, SubscriptionRenewed::class);
});

test('DID_FAIL_TO_RENEW webhook triggers PaymentFailed notification', function () {
    Notification::fake();

    $u = User::factory()->create([
        'plan_key' => 'plus',
        'subscription_status' => 'active',
        'subscription_original_transaction_id' => 'TXF',
        'apn_device_token' => 'HEXTOKEN',
    ]);

    $signedTx = base64_encode((string) json_encode([
        'productId' => 'com.lukehogan.flashcards.plus.annual',
        'originalTransactionId' => 'TXF',
        'expiresDate' => now()->addMonth()->valueOf(),
    ]));
    $signedPayload = base64_encode((string) json_encode([
        'notificationType' => 'DID_FAIL_TO_RENEW',
        'data' => ['signedTransactionInfo' => $signedTx],
    ]));

    $this->postJson('/api/v1/webhooks/app-store', ['signedPayload' => $signedPayload])->assertOk();

    Notification::assertSentTo($u, PaymentFailed::class);
});
