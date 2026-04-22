<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\SubTopicFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * SubTopic model.
 *
 * Represents a named section within a Deck, used to group flashcards
 * by sub-category. Timestamps tracked in milliseconds for sync protocol.
 */
class SubTopic extends Model
{
    /** @use HasFactory<SubTopicFactory> */
    use HasFactory, HasUuids;

    protected $fillable = [
        'deck_id',
        'name',
        'position',
        'color_hint',
        'updated_at_ms',
        'deleted_at_ms',
    ];

    protected $casts = [
        'updated_at_ms' => 'integer',
        'deleted_at_ms' => 'integer',
        'position' => 'integer',
    ];

    /**
     * Get the deck this sub-topic belongs to.
     *
     * @return BelongsTo<Deck, $this>
     */
    public function deck(): BelongsTo
    {
        return $this->belongsTo(Deck::class);
    }
}
