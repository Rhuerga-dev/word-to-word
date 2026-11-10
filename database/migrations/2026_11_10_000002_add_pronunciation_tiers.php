<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Niveles por sonido: g = Guiado (todo con ayuda), p = Práctica (ayuda solo si la pides), d = Dominio (sin modelo).
        Schema::table('phoneme_errors', function (Blueprint $table) {
            $table->string('tier', 1)->default('g');
            $table->unsignedTinyInteger('dominio_fails')->default(0); // talleres de Dominio fallados seguidos
        });
        // Lo que ya estaba dominado empieza en Dominio; lo que ya llevaba talleres aprobados, en Práctica.
        DB::table('phoneme_errors')->whereNotNull('mastered_on')->update(['tier' => 'd']);
        DB::table('phoneme_errors')->whereNull('mastered_on')->where('stage', '>=', 2)->update(['tier' => 'p']);
    }

    public function down(): void
    {
        Schema::table('phoneme_errors', fn (Blueprint $table) => $table->dropColumn(['tier', 'dominio_fails']));
    }
};
