<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sub_topics', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('deck_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->integer('position')->default(0);
            $table->string('color_hint')->nullable();
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->index(['deck_id', 'updated_at_ms']);
            $table->index(['deck_id', 'position']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sub_topics');
    }
};
