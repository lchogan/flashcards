<?php

declare(strict_types=1);

namespace App\Providers;

use App\Services\Auth\AppleIdentityVerifier;
use App\Services\Sync\Entities\DeckReader;
use App\Services\Sync\Entities\DeckUpserter;
use App\Services\Sync\Entities\SubTopicReader;
use App\Services\Sync\Entities\SubTopicUpserter;
use App\Services\Sync\Entities\TopicReader;
use App\Services\Sync\Entities\TopicUpserter;
use App\Services\Sync\SyncPullService;
use App\Services\Sync\SyncPushService;
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
    }

    /**
     * Bootstrap any application services.
     *
     * Registers entity-specific upserters and readers with the sync push/pull
     * services so each entity key is routed to the correct handler class.
     */
    public function boot(): void
    {
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
    }
}
