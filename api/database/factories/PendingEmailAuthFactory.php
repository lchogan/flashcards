<?php

declare(strict_types=1);

/**
 * PendingEmailAuthFactory — Eloquent factory for PendingEmailAuth.
 *
 * Purpose:
 *   Produce realistic pending-magic-link rows for tests (consume-endpoint
 *   happy/expired/consumed paths in later tasks).
 *
 * Key concepts:
 *   - `token_hash` is a sha256 of a random hex string so tests can hash
 *     the plaintext token the same way the service does.
 */

namespace Database\Factories;

use App\Models\PendingEmailAuth;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<PendingEmailAuth>
 */
class PendingEmailAuthFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'email' => fake()->unique()->safeEmail(),
            'token_hash' => hash('sha256', bin2hex(random_bytes(32))),
            'expires_at' => now()->addMinutes(15),
            'consumed_at' => null,
        ];
    }
}
