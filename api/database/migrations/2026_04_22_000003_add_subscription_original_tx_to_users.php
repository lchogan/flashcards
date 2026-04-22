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
            $table->string('subscription_original_transaction_id')->nullable()->after('subscription_product_id');
            $table->index('subscription_original_transaction_id');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['subscription_original_transaction_id']);
            $table->dropColumn('subscription_original_transaction_id');
        });
    }
};
