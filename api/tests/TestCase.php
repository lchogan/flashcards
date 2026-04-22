<?php

declare(strict_types=1);

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    /**
     * When a test boots the database (e.g. via RefreshDatabase), seed the
     * canonical plan matrix so entitlement gates behave the same way in tests
     * as they do in production. Individual tests can still override `plan_key`
     * on their factory users to exercise cap-triggered denies.
     */
    protected function setUpTraits(): array
    {
        $uses = parent::setUpTraits();

        if (
            isset($uses[\Illuminate\Foundation\Testing\RefreshDatabase::class])
            && class_exists(\Database\Seeders\PlanSeeder::class)
        ) {
            $this->artisan('db:seed', ['--class' => \Database\Seeders\PlanSeeder::class]);
        }

        return $uses;
    }
}
