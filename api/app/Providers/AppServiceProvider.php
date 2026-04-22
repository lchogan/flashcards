<?php

declare(strict_types=1);

namespace App\Providers;

use App\Services\Auth\AppleIdentityVerifier;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     *
     * Binds AppleIdentityVerifier as a singleton so the JWKS fetcher closure
     * is shared across the request lifecycle. The closure fetches Apple's
     * public keys from https://appleid.apple.com/auth/keys on demand; consumers
     * needing caching can wrap this fetcher in their own memoizing layer.
     */
    public function register(): void
    {
        $this->app->singleton(AppleIdentityVerifier::class, function () {
            return new AppleIdentityVerifier(
                clientId: config('services.apple.client_id', 'com.lukehogan.flashcards'),
                jwksFetcher: fn () => json_decode(file_get_contents('https://appleid.apple.com/auth/keys'), true),
            );
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
