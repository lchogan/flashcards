<?php

declare(strict_types=1);

namespace App\Providers;

use App\Services\Auth\AppleIdentityVerifier;
use App\Services\Entitlements\EntitlementChecker;
use App\Services\Subscriptions\AppStoreVerifier;
use App\Services\Sync\Entities\CardReader;
use App\Services\Sync\Entities\CardSubTopicReader;
use App\Services\Sync\Entities\CardSubTopicUpserter;
use App\Services\Sync\Entities\CardUpserter;
use App\Services\Sync\Entities\DeckReader;
use App\Services\Sync\Entities\DeckUpserter;
use App\Services\Sync\Entities\ReviewReader;
use App\Services\Sync\Entities\ReviewUpserter;
use App\Services\Sync\Entities\SessionReader;
use App\Services\Sync\Entities\SessionUpserter;
use App\Services\Sync\Entities\SubTopicReader;
use App\Services\Sync\Entities\SubTopicUpserter;
use App\Services\Sync\Entities\TopicReader;
use App\Services\Sync\Entities\TopicUpserter;
use App\Services\Sync\SyncPullService;
use App\Services\Sync\SyncPushService;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
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

        $this->app->singleton(SyncPushService::class);

        $this->app->singleton(SyncPullService::class);

        $this->app->singleton(EntitlementChecker::class);

        $this->app->singleton(AppStoreVerifier::class);
    }

    /**
     * Bootstrap any application services.
     *
     * Registers entity-specific upserters and readers with the sync push/pull
     * services so each entity key is routed to the correct handler class.
     */
    public function boot(): void
    {
        // Named rate limiter for authed API traffic. Scopes to the user when
        // Sanctum has resolved one, falls back to IP otherwise so unauthed
        // probes on the same endpoint don't share a bucket with signed-in
        // users.
        RateLimiter::for('api-authed', function (Request $request) {
            // Prefer the authenticated user's id (set by auth:sanctum which
            // runs ahead of throttle in the middleware pipeline). Falls back
            // to the bearer token's sha1 when user() is not yet resolved so
            // requests from different devices on a shared IP still get
            // independent buckets.
            $userId = $request->user()?->getAuthIdentifier();
            if ($userId !== null) {
                return Limit::perMinute(60)->by((string) $userId);
            }

            $bearer = $request->bearerToken();
            if ($bearer !== null && $bearer !== '') {
                return Limit::perMinute(60)->by('bearer:'.sha1($bearer));
            }

            return Limit::perMinute(60)->by('ip:'.($request->ip() ?? 'unknown'));
        });

        app(SyncPushService::class)
            ->register('topics', TopicUpserter::class);
        app(SyncPullService::class)
            ->register('topics', TopicReader::class);
        app(SyncPushService::class)
            ->register('decks', DeckUpserter::class);
        app(SyncPullService::class)
            ->register('decks', DeckReader::class);
        app(SyncPushService::class)
            ->register('sub_topics', SubTopicUpserter::class);
        app(SyncPullService::class)
            ->register('sub_topics', SubTopicReader::class);
        app(SyncPushService::class)
            ->register('cards', CardUpserter::class);
        app(SyncPullService::class)
            ->register('cards', CardReader::class);
        app(SyncPushService::class)
            ->register('card_sub_topics', CardSubTopicUpserter::class);
        app(SyncPullService::class)
            ->register('card_sub_topics', CardSubTopicReader::class);
        app(SyncPushService::class)
            ->register('reviews', ReviewUpserter::class);
        app(SyncPullService::class)
            ->register('reviews', ReviewReader::class);
        app(SyncPushService::class)
            ->register('sessions', SessionUpserter::class);
        app(SyncPullService::class)
            ->register('sessions', SessionReader::class);
    }
}
