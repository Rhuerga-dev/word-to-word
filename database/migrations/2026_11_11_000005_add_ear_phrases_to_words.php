<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Oído: lo que se escucha y se repite, de menos a más largo (palabra → frase → oración → oración larga).
        Schema::table('words', function (Blueprint $table) {
            $table->string('phrase', 80)->nullable();          // 2–5 palabras: "pay the rent"
            $table->string('sentence_long')->nullable();       // 12–18 palabras, natural
        });
    }

    public function down(): void
    {
        Schema::table('words', function (Blueprint $table) {
            $table->dropColumn(['phrase', 'sentence_long']);
        });
    }
};
