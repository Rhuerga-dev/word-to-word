<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Los cuidados de Brainy, la mascota (una fila por alumno). Solo añade una tabla nueva.
 * Guarda marcas de tiempo, no barras: así el hambre y el ánimo bajan aunque la app esté cerrada.
 * Se borra con la cuenta (cascade) y al reiniciar el progreso.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            // Comida y ánimo: cuántos corazones tenía (0–4) y cuándo se midió.
            $table->float('food')->default(2);
            $table->timestamp('food_at')->nullable();
            $table->float('joy')->default(2);
            $table->timestamp('joy_at')->nullable();
            $table->timestamp('cured_at')->nullable();          // última medicina
            $table->timestamp('last_care_at')->nullable();      // último cuidado (para la hibernación)
            $table->date('last_care_day')->nullable();
            $table->unsignedInteger('care_days')->default(0);   // días distintos en que la cuidaste
            // Qué practicas más (en puntos): decide su forma adulta.
            $table->unsignedInteger('vocab_points')->default(0);
            $table->unsignedInteger('ear_points')->default(0);
            $table->unsignedInteger('talk_points')->default(0);
            $table->unsignedTinyInteger('stage_max')->default(0);  // la etapa nunca baja
            $table->string('form', 20)->nullable();                // forma adulta, fijada al llegar a la última etapa
            $table->json('history')->nullable();                   // [{stage, at}] su árbol de evolución
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pets');
    }
};
