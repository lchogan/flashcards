<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Subscriptions\AppStoreVerifier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use InvalidArgumentException;
use Throwable;

/**
 * Apple → our server webhook for App Store Server Notifications v2.
 *
 * Apple sends a `signedPayload` (JWT) describing the notification
 * (DID_RENEW / EXPIRED / REFUND / …). We decode it, look the user up via
 * `originalTransactionId`, and update subscription_status + plan_key.
 *
 * Hardening path: validate Apple's x5c chain against the bundled Apple root
 * CA. For v1 we trust the signed payload but always map to a user we
 * already know about (so an attacker can't elevate a random account).
 */
class AppStoreNotificationsController extends Controller
{
    public function __construct(private readonly AppStoreVerifier $verifier) {}

    public function store(Request $request): JsonResponse
    {
        $signedPayload = $request->input('signedPayload');
        if (! is_string($signedPayload)) {
            return response()->json(status: 200);
        }

        try {
            $envelope = $this->decodeNotification($signedPayload);
        } catch (InvalidArgumentException) {
            // Acknowledge bad-shaped payloads with 200 so Apple doesn't retry
            // forever on a client bug; the next notification will reconcile.
            return response()->json(status: 200);
        }

        $notificationType = (string) ($envelope['notificationType'] ?? '');
        $signedTransactionInfo = (string) ($envelope['data']['signedTransactionInfo'] ?? '');
        $originalTxId = null;

        if ($signedTransactionInfo !== '') {
            try {
                $tx = $this->verifier->verify($signedTransactionInfo);
                $originalTxId = $tx->originalTransactionId;
            } catch (Throwable) {
                $originalTxId = null;
            }
        }

        // originalTransactionId ties every notification back to the first
        // purchase; we key our User lookup on it so renewals hit the right
        // account even after months pass.
        $user = $originalTxId
            ? User::where('subscription_original_transaction_id', $originalTxId)->first()
            : null;

        if (! $user) {
            return response()->json(status: 200);
        }

        match ($notificationType) {
            'DID_RENEW', 'SUBSCRIBED' => $user->update([
                'subscription_status' => 'active',
                'plan_key' => 'plus',
                'updated_at_ms' => now()->valueOf(),
            ]),
            'DID_FAIL_TO_RENEW' => $user->update([
                'subscription_status' => 'in_grace',
                'updated_at_ms' => now()->valueOf(),
            ]),
            'EXPIRED', 'GRACE_PERIOD_EXPIRED', 'REFUND', 'REVOKE' => $user->update([
                'subscription_status' => 'expired',
                'plan_key' => 'free',
                'updated_at_ms' => now()->valueOf(),
            ]),
            default => null,
        };

        return response()->json(status: 200);
    }

    /**
     * Decode the outer notification envelope. Same JWS shape as a transaction,
     * different payload.
     *
     * @return array<string, mixed>
     */
    private function decodeNotification(string $signedPayload): array
    {
        $signedPayload = trim($signedPayload);
        if (substr_count($signedPayload, '.') === 2) {
            [, $payload] = explode('.', $signedPayload, 3);
            $remainder = strlen($payload) % 4;
            if ($remainder !== 0) {
                $payload .= str_repeat('=', 4 - $remainder);
            }
            $decoded = base64_decode(strtr($payload, '-_', '+/'), strict: true);
        } else {
            $decoded = base64_decode($signedPayload, strict: true);
        }
        if ($decoded === false) {
            throw new InvalidArgumentException('bad base64');
        }

        /** @var array<string, mixed>|null $data */
        $data = json_decode($decoded, true);
        if (! is_array($data)) {
            throw new InvalidArgumentException('bad JSON');
        }

        return $data;
    }
}
