<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Significados fáciles para el ejercicio de Oído (de menos a más difícil).
        Schema::table('words', function (Blueprint $table) {
            $table->string('gloss', 60)->nullable();        // 1–3 palabras muy simples: "last day", "paper with price"
            $table->string('emoji', 16)->nullable();         // si un emoji lo muestra claro
            $table->string('definition_easy')->nullable();   // definición solo con palabras muy comunes
        });
    }

    public function down(): void
    {
        Schema::table('words', function (Blueprint $table) {
            $table->dropColumn(['gloss', 'emoji', 'definition_easy']);
        });
    }
};
