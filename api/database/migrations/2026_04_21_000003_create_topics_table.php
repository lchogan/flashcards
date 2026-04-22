<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('topics', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('color_hint')->nullable();
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'updated_at_ms']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('topics');
    }
};
