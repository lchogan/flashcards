<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Asset;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Asset> */
class AssetFactory extends Factory
{
    protected $model = Asset::class;

    /** @return array<string, mixed> */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'mime_type' => 'image/jpeg',
            'upload_status' => 'pending',
            'updated_at_ms' => now()->getTimestampMs(),
        ];
    }
}
