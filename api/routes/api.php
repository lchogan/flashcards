<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\AccountController;
use App\Http\Controllers\Api\V1\AppleAuthController;
use App\Http\Controllers\Api\V1\AppStoreNotificationsController;
use App\Http\Controllers\Api\V1\EntitlementsController;
use App\Http\Controllers\Api\V1\MagicLinkController;
use App\Http\Controllers\Api\V1\MeController;
use App\Http\Controllers\Api\V1\ReminderController;
use App\Http\Controllers\Api\V1\SubscriptionController;
use App\Http\Controllers\Api\V1\SyncPullController;
use App\Http\Controllers\Api\V1\SyncPushController;
use App\Http\Controllers\Api\V1\TokenController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// Authed v1 routes: 60 req/min scoped to the authenticated user (see the
// `api-authed` limiter in AppServiceProvider::boot). Keyed on user id so
// two users sharing an IP don't deplete each other's bucket.
Route::middleware(['auth:sanctum', 'throttle:api-authed'])->prefix('v1')->group(function () {
    Route::post('/sync/push', SyncPushController::class);
    Route::get('/sync/pull', SyncPullController::class);
    Route::get('/me', [MeController::class, 'show']);
    Route::patch('/me', [MeController::class, 'update']);
    Route::post('/me/device-token', [MeController::class, 'registerDeviceToken']);

    Route::get('/me/entitlements', [EntitlementsController::class, 'show']);

    Route::get('/reminders', [ReminderController::class, 'index']);
    Route::post('/reminders', [ReminderController::class, 'store']);
    Route::patch('/reminders/{id}', [ReminderController::class, 'update']);
    Route::delete('/reminders/{id}', [ReminderController::class, 'destroy']);

    Route::post('/subscriptions/verify', [SubscriptionController::class, 'verify']);

    Route::delete('/me', [AccountController::class, 'destroy']);
});

// Apple App Store Server Notifications v2 — unauthenticated, signed by Apple.
Route::post('/v1/webhooks/app-store', [AppStoreNotificationsController::class, 'store']);

Route::prefix('v1')->group(function () {
    Route::post('/auth/apple', [AppleAuthController::class, 'store']);

    Route::post('/auth/magic-link/request', [MagicLinkController::class, 'request'])
        ->middleware('throttle:5,60');

    Route::post('/auth/magic-link/consume', [MagicLinkController::class, 'consume']);

    Route::post('/auth/refresh', [TokenController::class, 'refresh']);
});
