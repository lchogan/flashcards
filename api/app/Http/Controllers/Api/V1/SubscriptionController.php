<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Subscriptions\AppStoreVerifier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use InvalidArgumentException;

/**
 * POST /v1/subscriptions/verify
 *
 * Called by the iOS client immediately after a successful StoreKit 2
 * purchase. Body is `{ "jws": "<jwsRepresentation>" }`. We decode the
 * transaction, flip the user to Plus, and return the new plan snapshot so
 * EntitlementsManager can refresh without a second hop.
 *
 * Authoritative state reconciliation happens via the App Store Server
 * Notifications v2 webhook (AppStoreNotificationsController) — that's where
 * renewals, refunds, and revocations come from.
 */
class SubscriptionController extends Controller
{
    public function __construct(private readonly AppStoreVerifier $verifier) {}

    public function verify(Request $request): JsonResponse
    {
        $data = $request->validate([
            'jws' => ['sometimes', 'string'],
            'signed_transaction' => ['sometimes', 'string'],
        ]);
        $signed = $data['jws'] ?? $data['signed_transaction'] ?? null;
        if ($signed === null) {
            return response()->json(['error' => 'jws required'], 422);
        }

        try {
            $tx = $this->verifier->verify($signed);
        } catch (InvalidArgumentException $e) {
            return response()->json(['error' => $e->getMessage()], 422);
        }

        $user = $request->user();
        $user->update([
            'subscription_status' => 'active',
            'subscription_product_id' => $tx->productId,
            'subscription_original_transaction_id' => $tx->originalTransactionId,
            'subscription_expires_at' => $tx->expiresAtMs > 0
                ? now()->createFromTimestampMs($tx->expiresAtMs)
                : null,
            'plan_key' => 'plus',
            'updated_at_ms' => now()->valueOf(),
        ]);

        return response()->json([
            'plan_key' => 'plus',
            'subscription_status' => 'active',
            'subscription_expires_at' => $tx->expiresAtMs > 0
                ? now()->createFromTimestampMs($tx->expiresAtMs)->toIso8601String()
                : null,
            'expires_at_ms' => $tx->expiresAtMs,
        ]);
    }
}
