<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Plan;
use Illuminate\Database\Seeder;

/**
 * Populates the `plans` table from config('plans.defaults').
 *
 * Idempotent — safe to run repeatedly. Keeps the canonical entitlement
 * matrix version-controlled in config/plans.php rather than in-database.
 */
class PlanSeeder extends Seeder
{
    public function run(): void
    {
        foreach (config('plans.defaults') as $key => $data) {
            Plan::updateOrCreate(
                ['key' => $key],
                [
                    'label' => $data['label'],
                    'entitlements' => $data['entitlements'],
                    'version' => 1,
                ],
            );
        }
    }
}
