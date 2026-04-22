<?php

declare(strict_types=1);

/**
 * SessionFactory — generates fake Session records for testing.
 *
 * Purpose:
 *   Provides sensible defaults for all required Session columns so tests can
 *   create study session rows with minimal boilerplate.
 *
 * Dependencies:
 *   - App\Models\Deck (parent deck, created via factory when not supplied)
 *   - App\Models\Session (the model being fabricated)
 *   - App\Models\User (owner of the deck, created via factory when not supplied)
 */

namespace Database\Factories;

use App\Models\Deck;
use App\Models\Session;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Session> */
class SessionFactory extends Factory
{
    protected $model = Session::class;

    /**
     * Define the model's default state.
     *
     * Generates a complete, valid Session row. user_id and deck_id default to
     * freshly-created User/Deck factories; callers should pass explicit values
     * when relational consistency matters.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'deck_id' => Deck::factory(),
            'mode' => 'smart',
            'started_at_ms' => now()->getTimestampMs(),
            'updated_at_ms' => now()->getTimestampMs(),
        ];
    }
}
