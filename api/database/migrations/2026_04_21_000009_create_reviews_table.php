<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reviews', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('card_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            // session_id FK deferred to Task 1.14 (sessions table not yet created).
            $table->uuid('session_id')->nullable();
            $table->unsignedTinyInteger('rating'); // 1-4
            $table->integer('review_duration_ms')->default(0);
            $table->bigInteger('rated_at_ms');
            $table->json('state_before');
            $table->json('state_after');
            $table->string('scheduler_version')->default('fsrs-6');
            $table->bigInteger('updated_at_ms');
            $table->timestamps();
            $table->index(['card_id', 'rated_at_ms']);
            $table->index(['user_id', 'updated_at_ms']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reviews');
    }
};
