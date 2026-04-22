<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('assets', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->string('mime_type');
            $table->integer('width')->nullable();
            $table->integer('height')->nullable();
            $table->bigInteger('bytes')->nullable();
            $table->string('r2_key')->nullable();
            $table->enum('upload_status', ['pending', 'uploaded', 'failed'])->default('pending');
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('assets');
    }
};
