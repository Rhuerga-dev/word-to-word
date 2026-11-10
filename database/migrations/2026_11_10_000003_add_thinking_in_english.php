<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Definición sencilla en inglés: las fichas avanzadas se estudian sin español.
        Schema::table('words', function (Blueprint $table) {
            $table->string('definition')->nullable();
        });

        // Cuánto tardas en empezar a hablar después de la pregunta (pensar en inglés = arrancar rápido).
        Schema::table('speaking_sessions', function (Blueprint $table) {
            $table->unsignedInteger('reaction_ms')->default(0);     // suma de los tiempos de arranque
            $table->unsignedInteger('reaction_turns')->default(0);  // turnos medidos
            $table->string('topic', 200)->nullable();               // tema de la narración
        });
    }

    public function down(): void
    {
        Schema::table('words', fn (Blueprint $table) => $table->dropColumn('definition'));
        Schema::table('speaking_sessions', fn (Blueprint $table) => $table->dropColumn(['reaction_ms', 'reaction_turns', 'topic']));
    }
};
