<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Tipo de error (tiempo verbal, preposición…) para ver en el panel qué es lo que más se repite.
        Schema::table('speaking_mistakes', function (Blueprint $table) {
            $table->string('category', 20)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('speaking_mistakes', fn (Blueprint $table) => $table->dropColumn('category'));
    }
};
