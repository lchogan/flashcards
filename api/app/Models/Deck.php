<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\DeckFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Deck model.
 *
 * Represents a named collection of flashcards belonging to a user, optionally
 * associated with a Topic. Timestamps tracked in milliseconds for sync protocol.
 */
class Deck extends Model
{
    /** @use HasFactory<DeckFactory> */
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id',
        'topic_id',
        'title',
        'description',
        'accent_color',
        'default_study_mode',
        'card_count',
        'last_studied_at_ms',
        'updated_at_ms',
        'deleted_at_ms',
    ];

    protected $casts = [
        'card_count' => 'integer',
        'last_studied_at_ms' => 'integer',
        'updated_at_ms' => 'integer',
        'deleted_at_ms' => 'integer',
    ];

    /**
     * Get the user that owns this deck.
     *
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the topic this deck belongs to, if any.
     *
     * @return BelongsTo<Topic, $this>
     */
    public function topic(): BelongsTo
    {
        return $this->belongsTo(Topic::class);
    }
}
