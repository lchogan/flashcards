<?php

declare(strict_types=1);

/**
 * Session model — represents a user's study session against a single deck.
 *
 * Purpose:
 *   Persists metadata about a completed or in-progress study session, including
 *   timing, accuracy and mastery delta. Supports soft-deletion via deleted_at_ms.
 *
 * Dependencies:
 *   - App\Models\User (session owner, BelongsTo)
 *   - App\Models\Deck (deck studied, BelongsTo)
 *
 * Key concepts:
 *   - Table name: `study_sessions` — avoids collision with Laravel's HTTP session
 *     table created by the default framework migration. The sync wire-format entity
 *     key remains `sessions` per docs/sync-wire-format.md.
 *   - UUID preservation: HasUuids is included; upserter uses firstOrNew + explicit
 *     $model->id assignment to avoid the trait regenerating client-supplied UUIDs.
 */

namespace App\Models;

use Database\Factories\SessionFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Study session — records one user study session against a deck.
 *
 * The underlying table is `study_sessions` to avoid colliding with Laravel's
 * HTTP session table. The sync wire-format entity key remains `sessions`.
 */
class Session extends Model
{
    /** @use HasFactory<SessionFactory> */
    use HasFactory, HasUuids;

    protected $table = 'study_sessions';

    protected $fillable = [
        'user_id', 'deck_id', 'mode', 'started_at_ms', 'ended_at_ms',
        'cards_reviewed', 'accuracy_pct', 'mastery_delta',
        'updated_at_ms', 'deleted_at_ms',
    ];

    protected $casts = [
        'started_at_ms' => 'integer',
        'ended_at_ms' => 'integer',
        'updated_at_ms' => 'integer',
        'deleted_at_ms' => 'integer',
        'cards_reviewed' => 'integer',
        'accuracy_pct' => 'float',
        'mastery_delta' => 'float',
    ];

    /**
     * Get the user who owns this session.
     *
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the deck this session was run against.
     *
     * @return BelongsTo<Deck, $this>
     */
    public function deck(): BelongsTo
    {
        return $this->belongsTo(Deck::class);
    }
}
