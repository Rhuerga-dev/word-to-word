<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * El alumno elige el color de su mascota. Solo añade una columna a `pets`.
 * color: una clave de la lista fija (blue, purple…) o null = el color neutro con el que nace.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pets', function (Blueprint $table) {
            $table->string('color', 12)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('pets', function (Blueprint $table) {
            $table->dropColumn('color');
        });
    }
};
