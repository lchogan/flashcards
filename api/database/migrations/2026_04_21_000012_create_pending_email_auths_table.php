<?php

declare(strict_types=1);

/**
 * Migration — create `pending_email_auths`.
 *
 * Purpose:
 *   Persist short-lived magic-link authentication attempts. Each row maps an
 *   email address to a one-time token (stored as a sha256 hash) with a TTL
 *   and a consumed-at marker so a token can only be redeemed once.
 *
 * Dependencies:
 *   - None (table is self-contained; no foreign keys).
 *
 * Key concepts:
 *   - `token_hash` stores sha256(token); the plaintext token is only ever in
 *     the recipient's email. We verify by hashing the inbound token and
 *     matching the hash column.
 *   - `expires_at` enforces the 15-minute default TTL (see MagicLinkService).
 *   - `consumed_at` nullable — set on first successful consumption to prevent
 *     token replay. A background job prunes rows past `expires_at`.
 */

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('pending_email_auths', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('email')->index();
            $table->string('token_hash');
            $table->timestamp('expires_at');
            $table->timestamp('consumed_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('pending_email_auths');
    }
};
