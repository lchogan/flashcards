<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, HasUuids, Notifiable;

    protected $fillable = [
        'email', 'name', 'avatar_url', 'auth_provider', 'auth_provider_id',
        'daily_goal_cards', 'reminder_time_local', 'reminder_enabled',
        'theme_preference', 'fsrs_weights', 'subscription_status',
        'subscription_expires_at', 'subscription_product_id',
        'image_quota_used_bytes', 'marketing_opt_in', 'updated_at_ms', 'deleted_at_ms',
    ];

    protected $casts = [
        'fsrs_weights' => 'array',
        'reminder_enabled' => 'boolean',
        'marketing_opt_in' => 'boolean',
        'subscription_expires_at' => 'datetime',
        'image_quota_used_bytes' => 'integer',
        'updated_at_ms' => 'integer',
        'deleted_at_ms' => 'integer',
    ];

    protected $hidden = ['auth_provider_id'];

    /**
     * Get all decks owned by this user.
     *
     * @return HasMany<Deck, $this>
     */
    public function decks(): HasMany
    {
        return $this->hasMany(Deck::class);
    }
}
