<?php

declare(strict_types=1);

use App\Http\Controllers\Api\V1\AppleAuthController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

Route::prefix('v1')->group(function () {
    Route::post('/auth/apple', [AppleAuthController::class, 'store']);
});
