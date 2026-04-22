<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('scheduled_delete_at')->nullable()->after('plan_key');
            $table->index('scheduled_delete_at');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['scheduled_delete_at']);
            $table->dropColumn('scheduled_delete_at');
        });
    }
};
