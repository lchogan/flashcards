<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Plan;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * GET /v1/me/entitlements
 *
 * Returns the authenticated user's plan snapshot — the plan key plus the raw
 * entitlement matrix iOS consumes to gate UI and call sites. Falls back to the
 * free plan if plan_key is unset or unknown.
 */
class EntitlementsController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        $planKey = $user->plan_key ?? config('plans.default_plan_key', 'free');
        $plan = Plan::where('key', $planKey)->first()
            ?? Plan::where('key', 'free')->firstOrFail();

        return response()->json([
            'plan_key' => $plan->key,
            'version' => $plan->version,
            'entitlements' => $plan->entitlements,
        ]);
    }
}
