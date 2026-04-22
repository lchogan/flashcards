<?php

declare(strict_types=1);

/**
 * SendMagicLinkEmail — queued job that emails a magic-link sign-in URL.
 *
 * Purpose:
 *   Deliver a one-time sign-in URL to a user's email. Runs on the queue so
 *   the HTTP request completes quickly (200 OK before the mailer network
 *   round-trip).
 *
 * Dependencies:
 *   - Illuminate\Support\Facades\Mail (raw-text delivery for MVP).
 *   - config('app.magic_link_host') — host rendered into the link URL.
 *
 * Key concepts:
 *   - Carries the plaintext token (intentionally) so it can be embedded in
 *     the email link. The token exists only in the queue payload and the
 *     recipient's inbox; the database only has the hash.
 *   - MVP sends a plain-text mail. Later phases will replace this with a
 *     Blade-rendered Mailable.
 */

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Mail;

final class SendMagicLinkEmail implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(
        public readonly string $email,
        public readonly string $token,
    ) {}

    /**
     * Send the magic-link email containing the sign-in URL.
     *
     * The host is read from `config('app.magic_link_host')` so staging and
     * production can vary the domain without code changes.
     */
    public function handle(): void
    {
        $host = config('app.magic_link_host');
        $url = "https://{$host}/auth/consume?t={$this->token}";

        Mail::raw("Tap to sign in: {$url}", function ($msg) {
            $msg->to($this->email)->subject('Sign in to Flashcards');
        });
    }
}
