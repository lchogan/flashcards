<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * DELETE /v1/me
 *
 * Schedules the user for a 30-day grace period then hard deletes their
 * account (data + user row) via the HardDeleteExpiredUsers job. The grace
 * period gives users a chance to change their mind and satisfies
 * App Store Review 5.1.1 guidelines on account deletion.
 */
class AccountController extends Controller
{
    public function destroy(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->update(['scheduled_delete_at' => now()->addDays(30)]);

        // Revoke all active tokens so the session ends immediately — the
        // 30-day window is server-side recovery only, the client is out.
        $user->tokens()->delete();

        return response()->json(status: 204);
    }
}
