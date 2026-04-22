<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Reminder;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Reminder>
 */
class ReminderFactory extends Factory
{
    protected $model = Reminder::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'time_local' => '08:30',
            'enabled' => true,
            'updated_at_ms' => now()->valueOf(),
        ];
    }
}
