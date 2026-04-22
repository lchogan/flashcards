<?php

declare(strict_types=1);

/**
 * MagicLinkService — issue single-use magic-link tokens for email auth.
 *
 * Purpose:
 *   Mint a 64-character hex token, persist its sha256 hash alongside the
 *   (lowercased) email and a TTL, and return the plaintext token to the
 *   caller for delivery via email. The hash-only storage means a DB leak
 *   does not compromise in-flight sign-in links.
 *
 * Dependencies:
 *   - App\Models\PendingEmailAuth (persistence).
 *   - PHP's `random_bytes` (CSPRNG) for token entropy.
 *
 * Key concepts:
 *   - Tokens are 32 random bytes hex-encoded (64 chars, ~256 bits).
 *   - Default TTL: 15 minutes; tunable via constructor.
 *   - Emails are lowercased at storage time to make later lookups
 *     case-insensitive without requiring ILIKE.
 */

namespace App\Services\Auth;

use App\Models\PendingEmailAuth;

final class MagicLinkService
{
    public function __construct(private readonly int $ttlMinutes = 15) {}

    /**
     * Issue a new pending-auth row for the given email and return the
     * plaintext token (to be emailed) alongside the row id.
     *
     * @param  string  $email  Plaintext email address (case-insensitive).
     * @return array{auth_id: string, token: string}
     *
     * @throws \Exception If the CSPRNG fails to produce random bytes.
     */
    public function issue(string $email): array
    {
        $token = bin2hex(random_bytes(32));

        $row = PendingEmailAuth::create([
            'email' => strtolower($email),
            'token_hash' => hash('sha256', $token),
            'expires_at' => now()->addMinutes($this->ttlMinutes),
        ]);

        return ['auth_id' => $row->id, 'token' => $token];
    }
}
