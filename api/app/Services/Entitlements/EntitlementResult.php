<?php

declare(strict_types=1);

namespace App\Services\Entitlements;

/**
 * Value object returned by EntitlementChecker::can().
 *
 * - `allowed`: true when the user may perform the action
 * - `reason`: entitlement key that blocked the call when denied (for paywall routing)
 * - `limit`: numeric cap for max_count entitlements, null otherwise
 */
final class EntitlementResult
{
    public function __construct(
        public readonly bool $allowed,
        public readonly ?string $reason = null,
        public readonly ?int $limit = null,
    ) {}

    public static function allow(): self
    {
        return new self(true);
    }

    public static function deny(string $reason, ?int $limit = null): self
    {
        return new self(false, $reason, $limit);
    }
}
