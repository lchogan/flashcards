<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Server-side record of a local notification time the client should schedule.
 *
 * A Reminder is intentionally simple: the server only knows the user asked
 * for N times-of-day; the actual notification scheduling happens on-device
 * via UNUserNotificationCenter. We persist here so multiple devices stay in
 * sync and so the entitlement cap (`reminders.add`) is enforceable.
 */
class Reminder extends Model
{
    use HasFactory;
    use HasUuids;

    protected $fillable = ['user_id', 'time_local', 'enabled', 'updated_at_ms'];

    protected $casts = [
        'enabled' => 'boolean',
        'updated_at_ms' => 'integer',
    ];

    /**
     * @return BelongsTo<User, $this>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
