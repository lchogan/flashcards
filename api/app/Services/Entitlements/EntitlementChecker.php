<?php

declare(strict_types=1);

namespace App\Services\Entitlements;

use App\Models\Card;
use App\Models\Plan;
use App\Models\Reminder;
use App\Models\User;

/**
 * Determines whether a user may perform a given action under their plan.
 *
 * Entitlements are loaded from the `plans` table and come in two shapes:
 *   - boolean: { allowed: bool }
 *   - max_count: { max: int|null }    null means unlimited
 *
 * `can()` resolves an EntitlementResult; callers should fall back to a paywall
 * when `allowed === false` and route by `reason`.
 */
final class EntitlementChecker
{
    /**
     * @param  array<string, mixed>  $context  Extra hints for count-bounded checks
     *                                        (e.g. ['deck_id' => '…'] for cards.create_in_deck).
     */
    public function can(User $user, string $key, array $context = []): EntitlementResult
    {
        $plan = Plan::where('key', $user->plan_key ?? 'free')->first()
            ?? Plan::where('key', 'free')->first();

        if ($plan === null) {
            return EntitlementResult::deny($key);
        }

        $config = $plan->entitlements[$key] ?? null;
        if ($config === null) {
            return EntitlementResult::deny($key);
        }

        return match ($config['type']) {
            'boolean' => ($config['allowed'] ?? false)
                ? EntitlementResult::allow()
                : EntitlementResult::deny($key),
            'max_count' => $this->checkMaxCount($user, $key, $config, $context),
            default => EntitlementResult::deny($key),
        };
    }

    /**
     * @param  array<string, mixed>  $config
     * @param  array<string, mixed>  $context
     */
    private function checkMaxCount(User $user, string $key, array $config, array $context): EntitlementResult
    {
        $max = $config['max'] ?? null;
        if ($max === null) {
            return EntitlementResult::allow();
        }

        $current = $this->currentCount($user, $key, $context);

        return $current < $max
            ? EntitlementResult::allow()
            : EntitlementResult::deny($key, (int) $max);
    }

    /**
     * @param  array<string, mixed>  $context
     */
    private function currentCount(User $user, string $key, array $context): int
    {
        return match ($key) {
            'decks.create' => $user->decks()
                ->whereNull('deleted_at_ms')
                ->count(),
            'cards.create_in_deck' => isset($context['deck_id'])
                ? Card::where('deck_id', $context['deck_id'])
                    ->whereNull('deleted_at_ms')
                    ->count()
                : 0,
            'cards.create_total' => Card::whereIn(
                'deck_id',
                $user->decks()->select('id')
            )
                ->whereNull('deleted_at_ms')
                ->count(),
            'reminders.add' => Reminder::where('user_id', $user->id)
                ->where('enabled', true)
                ->count(),
            default => 0,
        };
    }
}
