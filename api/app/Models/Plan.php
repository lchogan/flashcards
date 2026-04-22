<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\PlanFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Server-side definition of a subscription plan.
 *
 * A Plan carries a canonical key ("free", "plus", "launch-grandfather"),
 * a human-readable label, and a JSON bag of entitlement rules that the
 * EntitlementChecker consults at request time.
 */
class Plan extends Model
{
    /** @use HasFactory<PlanFactory> */
    use HasFactory;

    use HasUuids;

    protected $fillable = ['key', 'label', 'entitlements', 'version'];

    protected $casts = [
        'entitlements' => 'array',
        'version' => 'integer',
    ];
}
