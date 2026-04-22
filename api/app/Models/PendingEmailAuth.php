<?php

declare(strict_types=1);

/**
 * PendingEmailAuth — Eloquent model for the `pending_email_auths` table.
 *
 * Purpose:
 *   Represent a pending magic-link authentication attempt: email address,
 *   hashed one-time token, expiry, and consumed-at marker. Consumed or
 *   expired rows are retained briefly for audit, then pruned.
 *
 * Dependencies:
 *   - Illuminate\Database\Eloquent\Model, HasUuids, HasFactory.
 *
 * Key concepts:
 *   - Primary key is a UUID (see HasUuids). The plaintext token never lives
 *     in the database — only its sha256 hash in `token_hash`.
 *   - `expires_at` and `consumed_at` are cast to Carbon for ergonomic
 *     comparisons in the consume flow (Task 0.35).
 */

namespace App\Models;

use Database\Factories\PendingEmailAuthFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PendingEmailAuth extends Model
{
    /** @use HasFactory<PendingEmailAuthFactory> */
    use HasFactory, HasUuids;

    /** @var list<string> */
    protected $fillable = ['email', 'token_hash', 'expires_at', 'consumed_at'];

    /** @var array<string, string> */
    protected $casts = [
        'expires_at' => 'datetime',
        'consumed_at' => 'datetime',
    ];
}
