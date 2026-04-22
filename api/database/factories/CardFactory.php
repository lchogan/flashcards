<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Card;
use App\Models\Deck;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Card factory.
 *
 * Generates test Card instances with randomized attributes suitable for
 * feature tests. FSRS scheduling fields default to null/zero to represent
 * a newly created card.
 *
 * @extends Factory<Card>
 */
class CardFactory extends Factory
{
    protected $model = Card::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'deck_id' => Deck::factory(),
            'front_text' => fake()->sentence(),
            'back_text' => fake()->sentence(),
            'front_image_asset_id' => null,
            'back_image_asset_id' => null,
            'position' => fake()->numberBetween(0, 100),
            'stability' => null,
            'difficulty' => null,
            'state' => 'new',
            'last_reviewed_at_ms' => null,
            'due_at_ms' => null,
            'lapses' => 0,
            'reps' => 0,
            'updated_at_ms' => now()->getTimestampMs(),
            'deleted_at_ms' => null,
        ];
    }
}
