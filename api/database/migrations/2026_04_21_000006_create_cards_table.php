<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('cards', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('deck_id')->constrained()->cascadeOnDelete();
            $table->text('front_text');
            $table->text('back_text');
            $table->uuid('front_image_asset_id')->nullable();
            $table->uuid('back_image_asset_id')->nullable();
            $table->integer('position')->default(0);
            $table->float('stability')->nullable();
            $table->float('difficulty')->nullable();
            $table->enum('state', ['new', 'learning', 'review', 'relearning'])->default('new');
            $table->bigInteger('last_reviewed_at_ms')->nullable();
            $table->bigInteger('due_at_ms')->nullable();
            $table->integer('lapses')->default(0);
            $table->integer('reps')->default(0);
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->index(['deck_id', 'updated_at_ms']);
            $table->index(['deck_id', 'due_at_ms']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cards');
    }
};
