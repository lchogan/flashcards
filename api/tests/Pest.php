<?php

declare(strict_types=1);

/**
 * Pest bootstrap — test suite wiring and shared test helpers.
 *
 * Purpose:
 *   Bind Laravel's TestCase to Feature/Unit suites, refresh the DB between
 *   feature tests, and expose global test helpers (e.g. Apple Sign In JWT
 *   fixtures) usable from any `test()` block.
 *
 * Dependencies:
 *   - Tests\TestCase (Laravel test harness)
 *   - firebase/php-jwt for signing fake Apple identity tokens
 *
 * Key concepts:
 *   - `appleTestKeys()` memoizes a 2048-bit RSA key pair plus a matching JWKS
 *     entry so the signer and verifier can agree on keys without hitting the
 *     network.
 */

use Firebase\JWT\JWT;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

uses(TestCase::class, RefreshDatabase::class)->in('Feature');
uses(TestCase::class)->in('Unit');

/**
 * Generate (once per process) a 2048-bit RSA key pair with a matching
 * single-entry JWKS. Cached for test-run speed and so the public JWKS
 * actually corresponds to the private key used to sign tokens.
 *
 * @return array{privatePem: string, jwks: array{keys: array<int, array<string, string>>}}
 */
function appleTestKeys(): array
{
    /** @var array{privatePem: string, jwks: array{keys: array<int, array<string, string>>}}|null $cached */
    static $cached = null;

    if ($cached !== null) {
        return $cached;
    }

    $private = openssl_pkey_new([
        'private_key_bits' => 2048,
        'private_key_type' => OPENSSL_KEYTYPE_RSA,
    ]);
    if ($private === false) {
        throw new RuntimeException('Failed to generate test RSA key pair');
    }

    openssl_pkey_export($private, $privatePem);
    $details = openssl_pkey_get_details($private);
    if ($details === false || ! isset($details['rsa']['n'], $details['rsa']['e'])) {
        throw new RuntimeException('Failed to read RSA key details');
    }

    // JWK public entry; `kid` must match the `kid` in tokens we sign so
    // JWT::decode can pick the right key from the set.
    $jwk = [
        'kty' => 'RSA',
        'kid' => 'test-apple-kid',
        'use' => 'sig',
        'alg' => 'RS256',
        'n' => rtrim(strtr(base64_encode($details['rsa']['n']), '+/', '-_'), '='),
        'e' => rtrim(strtr(base64_encode($details['rsa']['e']), '+/', '-_'), '='),
    ];

    $cached = [
        'privatePem' => $privatePem,
        'jwks' => ['keys' => [$jwk]],
    ];

    return $cached;
}

/**
 * Public JWKS matching the test key pair. Inject this as the `jwksFetcher`
 * callable when constructing `AppleIdentityVerifier` in tests.
 *
 * @return array{keys: array<int, array<string, string>>}
 */
function fakeAppleJwks(): array
{
    return appleTestKeys()['jwks'];
}

/**
 * Sign a fake Apple identity token with the cached test key pair.
 *
 * @param  non-empty-string  $sub  Apple subject (stable user ID).
 * @param  string|null  $email  Optional email claim; omitted from payload when null.
 * @param  non-empty-string  $aud  Expected audience — usually the app's Bundle ID.
 * @param  string|null  $iss  Optional issuer override for testing negative cases.
 *                            Defaults to Apple's real issuer.
 */
function makeFakeAppleIdentityToken(
    string $sub,
    ?string $email,
    string $aud,
    ?string $iss = null,
): string {
    $keys = appleTestKeys();
    $payload = [
        'iss' => $iss ?? 'https://appleid.apple.com',
        'aud' => $aud,
        'sub' => $sub,
        'iat' => time(),
        'exp' => time() + 3600,
    ];
    if ($email !== null) {
        $payload['email'] = $email;
    }

    return JWT::encode($payload, $keys['privatePem'], 'RS256', 'test-apple-kid');
}
