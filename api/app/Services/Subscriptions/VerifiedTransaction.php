<?php

declare(strict_types=1);

namespace App\Services\Subscriptions;

/**
 * Plain value object representing a decoded App Store transaction.
 *
 * Fields are the minimum we need to flip `users.plan_key` and record the
 * expiry. The full StoreKit JWS carries many more claims; see
 * https://developer.apple.com/documentation/appstoreserverapi/jwstransactiondecodedpayload
 */
final class VerifiedTransaction
{
    public function __construct(
        public readonly string $productId,
        public readonly string $originalTransactionId,
        public readonly int $expiresAtMs,
        public readonly string $environment,
    ) {}
}
