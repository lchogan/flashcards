<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Deck;
use App\Models\SubTopic;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * SubTopic factory.
 *
 * Generates test SubTopic instances with randomized attributes.
 *
 * @extends Factory<SubTopic>
 */
class SubTopicFactory extends Factory
{
    protected $model = SubTopic::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'deck_id' => Deck::factory(),
            'name' => fake()->word(),
            'position' => fake()->numberBetween(0, 10),
            'color_hint' => null,
            'updated_at_ms' => now()->getTimestampMs(),
            'deleted_at_ms' => null,
        ];
    }
}
