<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reminders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->time('time_local');
            $table->boolean('enabled')->default(true);
            $table->bigInteger('updated_at_ms');
            $table->timestamps();

            $table->index(['user_id', 'enabled']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reminders');
    }
};
