<?php

declare(strict_types=1);

use App\Services\Auth\AppleIdentityVerifier;

test('verifies a valid Apple identity token and returns subject + email', function () {
    $verifier = new AppleIdentityVerifier(
        clientId: 'com.lukehogan.flashcards',
        jwksFetcher: fn () => fakeAppleJwks(),
    );

    $token = makeFakeAppleIdentityToken(
        sub: 'APPLE_UID_123',
        email: 'user@example.com',
        aud: 'com.lukehogan.flashcards',
    );

    $claims = $verifier->verify($token);

    expect($claims->subject)->toBe('APPLE_UID_123')
        ->and($claims->email)->toBe('user@example.com');
});

test('rejects a token with wrong audience', function () {
    $verifier = new AppleIdentityVerifier(
        clientId: 'com.lukehogan.flashcards',
        jwksFetcher: fn () => fakeAppleJwks(),
    );

    $token = makeFakeAppleIdentityToken(
        sub: 'x',
        email: 'x@x',
        aud: 'wrong.audience',
    );

    expect(fn () => $verifier->verify($token))
        ->toThrow(RuntimeException::class, 'Audience mismatch');
});

test('rejects a token with wrong issuer', function () {
    $verifier = new AppleIdentityVerifier(
        clientId: 'com.lukehogan.flashcards',
        jwksFetcher: fn () => fakeAppleJwks(),
    );

    $token = makeFakeAppleIdentityToken(
        sub: 'APPLE_UID_123',
        email: 'user@example.com',
        aud: 'com.lukehogan.flashcards',
        iss: 'https://evil.example.com',
    );

    expect(fn () => $verifier->verify($token))
        ->toThrow(RuntimeException::class, 'Issuer mismatch');
});
