<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\AppleAuthController;
use App\Http\Controllers\Api\V1\MagicLinkController;
use App\Http\Controllers\Api\V1\MeController;
use App\Http\Controllers\Api\V1\SyncPullController;
use App\Http\Controllers\Api\V1\SyncPushController;
use App\Http\Controllers\Api\V1\TokenController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::post('/sync/push', SyncPushController::class);
    Route::get('/sync/pull', SyncPullController::class);
    Route::get('/me', [MeController::class, 'show']);
    Route::patch('/me', [MeController::class, 'update']);
});

Route::prefix('v1')->group(function () {
    Route::post('/auth/apple', [AppleAuthController::class, 'store']);

    Route::post('/auth/magic-link/request', [MagicLinkController::class, 'request'])
        ->middleware('throttle:5,60');

    Route::post('/auth/magic-link/consume', [MagicLinkController::class, 'consume']);

    Route::post('/auth/refresh', [TokenController::class, 'refresh']);
});
