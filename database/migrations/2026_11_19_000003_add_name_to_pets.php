<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * El alumno le pone nombre a su mascota. Solo añade dos columnas a `pets`.
 * - name: el nombre elegido (null = se llama «Brainy»).
 * - welcomed_at: cuándo vio su nacimiento y respondió a «¿cómo me quieres llamar?» (aunque dijera «luego»).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pets', function (Blueprint $table) {
            $table->string('name', 20)->nullable();
            $table->timestamp('welcomed_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('pets', function (Blueprint $table) {
            $table->dropColumn(['name', 'welcomed_at']);
        });
    }
};
