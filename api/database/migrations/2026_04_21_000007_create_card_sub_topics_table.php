<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('card_sub_topics', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('card_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('sub_topic_id')->constrained('sub_topics')->cascadeOnDelete();
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->unique(['card_id', 'sub_topic_id']);
            $table->index('updated_at_ms');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('card_sub_topics');
    }
};
