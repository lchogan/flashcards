<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\ReviewFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Review model — immutable append-only record of a single card review event.
 *
 * Reviews are the source of truth for a card's FSRS state; Task 1.13's
 * ReplayReviewsForCard recomputes the Card cache from this log. UPDATED_AT
 * is null because reviews never mutate after insert.
 *
 * Dependencies:
 *   - App\Models\Card (the card reviewed)
 *   - App\Models\User (the reviewer)
 *   - Database\Factories\ReviewFactory
 *
 * Key concepts:
 *   - Append-only: once inserted a review row is never modified. There is no
 *     LWW update path. Duplicate client-supplied UUIDs are silently rejected
 *     by ReviewUpserter.
 *   - state_before/state_after: JSON snapshots of the card's FSRS state at
 *     review time. Enables full replay without additional lookups.
 */
class Review extends Model
{
    /** @use HasFactory<ReviewFactory> */
    use HasFactory, HasUuids;

    public $timestamps = true;

    /** Reviews are append-only; there is no updated_at column. */
    const UPDATED_AT = null;

    protected $fillable = [
        'card_id', 'user_id', 'session_id', 'rating',
        'review_duration_ms', 'rated_at_ms', 'state_before', 'state_after',
        'scheduler_version', 'updated_at_ms',
    ];

    protected $casts = [
        'state_before' => 'array',
        'state_after' => 'array',
        'rating' => 'integer',
        'review_duration_ms' => 'integer',
        'rated_at_ms' => 'integer',
        'updated_at_ms' => 'integer',
    ];

    /**
     * Get the card this review was rated against.
     *
     * @return BelongsTo<Card, $this>
     */
    public function card(): BelongsTo
    {
        return $this->belongsTo(Card::class);
    }

    /**
     * Get the user who submitted this review.
     *
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
