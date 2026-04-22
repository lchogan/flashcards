<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('decks', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('topic_id')->nullable()->constrained('topics')->nullOnDelete();
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('accent_color')->default('amber');
            $table->enum('default_study_mode', ['smart', 'basic'])->default('smart');
            $table->integer('card_count')->default(0);
            $table->bigInteger('last_studied_at_ms')->nullable();
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'updated_at_ms']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('decks');
    }
};
