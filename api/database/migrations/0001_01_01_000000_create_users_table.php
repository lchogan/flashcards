<?php

declare(strict_types=1);

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
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('email')->unique();
            $table->string('name')->nullable();
            $table->string('avatar_url')->nullable();
            $table->enum('auth_provider', ['apple', 'email']);
            $table->string('auth_provider_id')->nullable();
            $table->unsignedSmallInteger('daily_goal_cards')->default(20);
            $table->time('reminder_time_local')->nullable();
            $table->boolean('reminder_enabled')->default(false);
            $table->enum('theme_preference', ['system', 'light', 'dark'])->default('system');
            $table->json('fsrs_weights')->nullable();
            $table->enum('subscription_status', ['free', 'active', 'in_grace', 'expired'])->default('free');
            $table->timestamp('subscription_expires_at')->nullable();
            $table->string('subscription_product_id')->nullable();
            $table->unsignedBigInteger('image_quota_used_bytes')->default(0);
            $table->boolean('marketing_opt_in')->default(false);
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->unique(['auth_provider', 'auth_provider_id']);
            $table->index('updated_at_ms');
        });

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('users');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('sessions');
    }
};
