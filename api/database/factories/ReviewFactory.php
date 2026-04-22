<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Card;
use App\Models\Review;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Review factory.
 *
 * Generates test Review instances representing a single card rating event.
 * Defaults to a simple "good" (rating=3) review with empty FSRS state snapshots
 * so tests can override only the fields they care about.
 *
 * @extends Factory<Review>
 */
class ReviewFactory extends Factory
{
    protected $model = Review::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'card_id' => Card::factory(),
            'user_id' => User::factory(),
            'session_id' => null,
            'rating' => 3,
            'review_duration_ms' => fake()->numberBetween(500, 10000),
            'rated_at_ms' => now()->getTimestampMs(),
            'state_before' => ['state' => 'new'],
            'state_after' => ['state' => 'learning', 'stability' => 1.0, 'difficulty' => 5.0],
            'scheduler_version' => 'fsrs-6',
            'updated_at_ms' => now()->getTimestampMs(),
        ];
    }
}
