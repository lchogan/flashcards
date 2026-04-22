<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\CardSubTopicFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * CardSubTopic model.
 *
 * Join table associating a Card with a SubTopic within the same Deck. Both
 * the card and the sub-topic must belong to the same Deck — cross-deck
 * associations are invalid and rejected at the upserter layer.
 * Timestamps tracked in milliseconds for the sync protocol.
 */
class CardSubTopic extends Model
{
    /** @use HasFactory<CardSubTopicFactory> */
    use HasFactory, HasUuids;

    protected $table = 'card_sub_topics';

    protected $fillable = [
        'card_id',
        'sub_topic_id',
        'updated_at_ms',
        'deleted_at_ms',
    ];

    protected $casts = [
        'updated_at_ms' => 'integer',
        'deleted_at_ms' => 'integer',
    ];

    /**
     * Get the card this association belongs to.
     *
     * @return BelongsTo<Card, $this>
     */
    public function card(): BelongsTo
    {
        return $this->belongsTo(Card::class);
    }

    /**
     * Get the sub-topic this association belongs to.
     *
     * @return BelongsTo<SubTopic, $this>
     */
    public function subTopic(): BelongsTo
    {
        return $this->belongsTo(SubTopic::class);
    }
}
