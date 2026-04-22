<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('study_sessions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('deck_id')->constrained()->cascadeOnDelete();
            $table->enum('mode', ['smart', 'basic']);
            $table->bigInteger('started_at_ms');
            $table->bigInteger('ended_at_ms')->nullable();
            $table->integer('cards_reviewed')->default(0);
            $table->float('accuracy_pct')->default(0);
            $table->float('mastery_delta')->default(0);
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'updated_at_ms']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('study_sessions');
    }
};
