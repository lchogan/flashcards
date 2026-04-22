<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Plan;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Not used in production seeding (PlanSeeder is authoritative), but present so
 * tests that need ad-hoc plans + the HasFactory generic annotation on Plan can
 * point at a real factory class.
 *
 * @extends Factory<Plan>
 */
class PlanFactory extends Factory
{
    protected $model = Plan::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'key' => 'free',
            'label' => 'Free',
            'entitlements' => [],
            'version' => 1,
        ];
    }
}
