<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Taller de pronunciación: progreso por sonido con repetición espaciada.
        Schema::table('phoneme_errors', function (Blueprint $table) {
            $table->unsignedTinyInteger('stage')->default(0);        // talleres aprobados seguidos (0..4)
            $table->unsignedTinyInteger('best_score')->nullable();   // mejor puntaje del sonido en el taller
            $table->unsignedInteger('sessions')->default(0);
            $table->date('practiced_on')->nullable();
            $table->date('next_practice')->nullable();
            $table->date('mastered_on')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('phoneme_errors', function (Blueprint $table) {
            $table->dropColumn(['stage', 'best_score', 'sessions', 'practiced_on', 'next_practice', 'mastered_on']);
        });
    }
};
