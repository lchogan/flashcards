<?php

declare(strict_types=1);

/*
 * Canonical plan defaults, mirrored into the `plans` table by PlanSeeder.
 *
 * Source of truth for the entitlement matrix in spec §11.1. Keep keys in sync
 * with App\Services\Entitlements\EntitlementKey on iOS.
 */

return [
    'default_plan_key' => 'free',
    'defaults' => [
        'free' => [
            'label' => 'Free',
            'entitlements' => [
                'decks.create' => ['type' => 'max_count', 'max' => 5],
                'cards.create_in_deck' => ['type' => 'max_count', 'max' => 200],
                'cards.create_total' => ['type' => 'max_count', 'max' => 500],
                'study.smart' => ['type' => 'boolean', 'allowed' => true],
                'study.basic' => ['type' => 'boolean', 'allowed' => true],
                'reminders.add' => ['type' => 'max_count', 'max' => 1],
                'new_card_limit.above_10' => ['type' => 'boolean', 'allowed' => false],
                'fsrs.personalized' => ['type' => 'boolean', 'allowed' => false],
                'images.use' => ['type' => 'boolean', 'allowed' => false],
                'import.csv' => ['type' => 'boolean', 'allowed' => false],
                'export.csv' => ['type' => 'boolean', 'allowed' => false],
                'export.json' => ['type' => 'boolean', 'allowed' => false],
            ],
        ],
        'plus' => [
            'label' => 'Plus',
            'entitlements' => [
                'decks.create' => ['type' => 'max_count', 'max' => null],
                'cards.create_in_deck' => ['type' => 'max_count', 'max' => null],
                'cards.create_total' => ['type' => 'max_count', 'max' => null],
                'study.smart' => ['type' => 'boolean', 'allowed' => true],
                'study.basic' => ['type' => 'boolean', 'allowed' => true],
                'reminders.add' => ['type' => 'max_count', 'max' => 3],
                'new_card_limit.above_10' => ['type' => 'boolean', 'allowed' => true],
                'fsrs.personalized' => ['type' => 'boolean', 'allowed' => false],
                'images.use' => ['type' => 'boolean', 'allowed' => false],
                'import.csv' => ['type' => 'boolean', 'allowed' => false],
                'export.csv' => ['type' => 'boolean', 'allowed' => false],
                'export.json' => ['type' => 'boolean', 'allowed' => false],
            ],
        ],
    ],
];
