<?php

declare(strict_types=1);

/**
 * AppleIdentityVerifier — verifies Apple Sign In identity tokens.
 *
 * Purpose:
 *   Given a raw JWT issued by Apple during Sign In with Apple, verify the
 *   signature (against Apple's published JWKS), plus the issuer, audience,
 *   and required claims. Returns the normalized subject + email on success.
 *
 * Dependencies:
 *   - firebase/php-jwt (v6 or v7) for JWKS parsing and JWT decoding.
 *
 * Key concepts:
 *   - Apple publishes its public signing keys as a JWKS at
 *     https://appleid.apple.com/auth/keys. The caller injects a fetcher so
 *     production code can memoize/cache the result and tests can stub it.
 *   - `clientId` must equal the app's Bundle ID (e.g.
 *     "com.lukehogan.flashcards"); Apple puts it in the token's `aud`.
 *   - This class does not trust the signature alone: it also checks
 *     issuer == "https://appleid.apple.com" and the presence of `sub`.
 */

namespace App\Services\Auth;

use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Firebase\JWT\SignatureInvalidException;
use RuntimeException;

final class AppleIdentityVerifier
{
    /**
     * @param  string  $clientId  The expected audience — app's Apple Bundle ID.
     * @param  callable  $jwksFetcher  A zero-arg callable returning Apple's JWKS as an associative array with a 'keys' entry.
     */
    public function __construct(
        private readonly string $clientId,
        private readonly mixed $jwksFetcher,
    ) {}

    /**
     * Verify an Apple identity token.
     *
     * Validates signature (via Apple's JWKS), issuer, audience, and presence
     * of a subject claim. Any failure surfaces as a RuntimeException — callers
     * typically translate this into an HTTP 401.
     *
     * @param  string  $token  The raw JWT string from Apple.
     * @return AppleClaims Normalized subject + optional email.
     *
     * @throws RuntimeException On audience mismatch, issuer mismatch, or missing subject.
     * @throws SignatureInvalidException On signature verification failure.
     * @throws \UnexpectedValueException On malformed token or unsupported algorithm.
     */
    public function verify(string $token): AppleClaims
    {
        $jwks = ($this->jwksFetcher)();
        $keys = JWK::parseKeySet($jwks);

        $decoded = JWT::decode($token, $keys);

        if (($decoded->aud ?? null) !== $this->clientId) {
            throw new RuntimeException('Audience mismatch');
        }
        if (($decoded->iss ?? null) !== 'https://appleid.apple.com') {
            throw new RuntimeException('Issuer mismatch');
        }
        if (! isset($decoded->sub)) {
            throw new RuntimeException('Missing subject');
        }

        return new AppleClaims(
            subject: (string) $decoded->sub,
            email: isset($decoded->email) ? (string) $decoded->email : null,
        );
    }
}

/**
 * AppleClaims — value object for verified Apple identity claims.
 *
 * Holds the subject (Apple's stable user ID) plus the optional email. Email
 * is only present on the first Sign In (unless the user shares it again), so
 * the caller must persist it when available.
 */
final class AppleClaims
{
    public function __construct(
        public readonly string $subject,
        public readonly ?string $email,
    ) {}
}
