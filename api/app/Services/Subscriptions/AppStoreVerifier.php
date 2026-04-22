<?php

declare(strict_types=1);

namespace App\Services\Subscriptions;

use InvalidArgumentException;

/**
 * Decodes StoreKit 2 JWS transaction payloads.
 *
 * v1 note: we trust the client-supplied JWS payload *in combination with* the
 * App Store Server Notifications v2 webhook. The webhook (signed by Apple,
 * received on our own route) flips authoritative state — `/verify` just
 * optimistically unlocks Plus for the session so the user doesn't see a
 * flash of "still free" after a successful purchase.
 *
 * Hardening path (tracked in Task 3.10 TODOs):
 *   - Fetch Apple's root CAs (https://www.apple.com/appleca/AppleIncRootCertificate.cer)
 *   - Walk the JWS x5c chain and verify the signing leaf is rooted in Apple
 *   - Cross-check by calling App Store Server API `getTransactionInfo`
 */
final class AppStoreVerifier
{
    /**
     * Decode a JWS-signed transaction. Accepts either:
     *   - the raw `jwsRepresentation` (header.payload.signature, base64url)
     *   - a base64-encoded JSON blob (used by fallback flows + tests)
     *
     * @throws InvalidArgumentException When the payload can't be parsed.
     */
    public function verify(string $signedPayload): VerifiedTransaction
    {
        $data = $this->decode($signedPayload);

        $productId = (string) ($data['productId'] ?? $data['productID'] ?? '');
        $originalTransactionId = (string) ($data['originalTransactionId'] ?? $data['originalTransactionID'] ?? '');
        $expiresAtMs = (int) ($data['expiresDate'] ?? $data['expirationDate'] ?? 0);
        $environment = (string) ($data['environment'] ?? 'Sandbox');

        if ($productId === '' || $originalTransactionId === '') {
            throw new InvalidArgumentException('Invalid transaction: missing productId or originalTransactionId');
        }

        return new VerifiedTransaction(
            productId: $productId,
            originalTransactionId: $originalTransactionId,
            expiresAtMs: $expiresAtMs,
            environment: $environment,
        );
    }

    /**
     * @return array<string, mixed>
     */
    private function decode(string $signedPayload): array
    {
        $signedPayload = trim($signedPayload);

        // Case 1: three-part JWS (header.payload.signature).
        if (substr_count($signedPayload, '.') === 2) {
            [, $payload] = explode('.', $signedPayload, 3);
            $decoded = $this->base64UrlDecode($payload);
        } else {
            // Case 2: base64 JSON blob (sandbox/test shortcut).
            $decoded = base64_decode($signedPayload, strict: true);
            if ($decoded === false) {
                throw new InvalidArgumentException('Payload is neither a JWS nor a valid base64 blob');
            }
        }

        /** @var array<string, mixed>|null $data */
        $data = json_decode($decoded, true);
        if (! is_array($data)) {
            throw new InvalidArgumentException('Payload is not valid JSON');
        }

        return $data;
    }

    private function base64UrlDecode(string $input): string
    {
        $remainder = strlen($input) % 4;
        if ($remainder !== 0) {
            $input .= str_repeat('=', 4 - $remainder);
        }
        $decoded = base64_decode(strtr($input, '-_', '+/'), strict: true);
        if ($decoded === false) {
            throw new InvalidArgumentException('Invalid base64url payload');
        }

        return $decoded;
    }
}
