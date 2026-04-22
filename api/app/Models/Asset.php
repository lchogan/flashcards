<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\AssetFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Asset model — reserved for v1.5 image uploads.
 *
 * The table exists so Card's front_image_asset_id / back_image_asset_id UUID
 * columns can round-trip via sync without referencing a missing relation. The
 * application-side upload pipeline, r2 integration, and sync upserter/reader
 * all land in v1.5 per spec §10.2. Until then, this model is inert.
 */
class Asset extends Model
{
    /** @use HasFactory<AssetFactory> */
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id', 'mime_type', 'width', 'height', 'bytes', 'r2_key',
        'upload_status', 'updated_at_ms', 'deleted_at_ms',
    ];

    protected $casts = [
        'width' => 'integer',
        'height' => 'integer',
        'bytes' => 'integer',
        'updated_at_ms' => 'integer',
        'deleted_at_ms' => 'integer',
    ];

    /**
     * Get the user that owns this asset.
     *
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
