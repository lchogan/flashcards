<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Card;
use App\Models\CardSubTopic;
use App\Models\SubTopic;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * CardSubTopic factory.
 *
 * Generates test CardSubTopic join records linking a Card to a SubTopic.
 * Note: in practice, the card and sub-topic must share the same Deck;
 * tests that rely on this constraint should wire them explicitly rather
 * than relying on the factory defaults.
 *
 * @extends Factory<CardSubTopic>
 */
class CardSubTopicFactory extends Factory
{
    protected $model = CardSubTopic::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'card_id' => Card::factory(),
            'sub_topic_id' => SubTopic::factory(),
            'updated_at_ms' => now()->getTimestampMs(),
            'deleted_at_ms' => null,
        ];
    }
}
