<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\CardFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Card model.
 *
 * Represents a single flashcard belonging to a Deck, carrying front/back
 * content and FSRS scheduling state. Timestamps tracked in milliseconds for
 * the sync protocol.
 */
class Card extends Model
{
    /** @use HasFactory<CardFactory> */
    use HasFactory, HasUuids;

    protected $fillable = [
        'deck_id',
        'front_text',
        'back_text',
        'front_image_asset_id',
        'back_image_asset_id',
        'position',
        'stability',
        'difficulty',
        'state',
        'last_reviewed_at_ms',
        'due_at_ms',
        'lapses',
        'reps',
        'updated_at_ms',
        'deleted_at_ms',
    ];

    protected $casts = [
        'position' => 'integer',
        'stability' => 'float',
        'difficulty' => 'float',
        'last_reviewed_at_ms' => 'integer',
        'due_at_ms' => 'integer',
        'lapses' => 'integer',
        'reps' => 'integer',
        'updated_at_ms' => 'integer',
        'deleted_at_ms' => 'integer',
    ];

    /**
     * Get the deck this card belongs to.
     *
     * @return BelongsTo<Deck, $this>
     */
    public function deck(): BelongsTo
    {
        return $this->belongsTo(Deck::class);
    }
}
