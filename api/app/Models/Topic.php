<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\TopicFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Topic model.
 *
 * Represents a collection of flashcards belonging to a user.
 * Timestamps tracked in milliseconds for sync protocol.
 */
class Topic extends Model
{
    /** @use HasFactory<TopicFactory> */
    use HasFactory, HasUuids;

    protected $fillable = ['user_id', 'name', 'color_hint', 'updated_at_ms', 'deleted_at_ms'];

    protected $casts = ['updated_at_ms' => 'integer', 'deleted_at_ms' => 'integer'];

    /**
     * Get the user that owns this topic.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
