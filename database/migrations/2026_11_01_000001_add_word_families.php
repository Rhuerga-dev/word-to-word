<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('words', function (Blueprint $table) {
            // Familia o tema de la palabra (body, food, fruits…). null = sin familia.
            $table->string('category', 24)->nullable()->index();
        });
        Schema::table('users', function (Blueprint $table) {
            // Familia elegida para las palabras nuevas. null = mezcla por frecuencia.
            $table->string('family', 24)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('words', fn (Blueprint $t) => $t->dropColumn('category'));
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn('family'));
    }
};
