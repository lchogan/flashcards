<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Deck;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Deck factory.
 *
 * Generates test Deck instances with randomized attributes.
 *
 * @extends Factory<Deck>
 */
class DeckFactory extends Factory
{
    protected $model = Deck::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'topic_id' => null,
            'title' => fake()->words(3, true),
            'description' => null,
            'accent_color' => 'amber',
            'default_study_mode' => 'smart',
            'card_count' => 0,
            'last_studied_at_ms' => null,
            'updated_at_ms' => now()->getTimestampMs(),
            'deleted_at_ms' => null,
        ];
    }
}
