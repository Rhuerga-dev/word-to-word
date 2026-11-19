<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Quién participa en cada experimento A/B (una fila por alumno y experimento). Solo añade una tabla nueva.
 * Guarda el grupo, el modo que de verdad usa, si lo cambió a mano y cuándo, y dos contadores de uso.
 * Se borra con la cuenta (cascade).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('experiment_participants', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('experiment', 30);
            $table->string('group', 12);                         // brainy | control
            $table->date('entered_day');                         // primer día en el experimento (día de estudio del alumno)
            $table->boolean('mode')->nullable();                 // modo real en uso: encendido / apagado
            $table->boolean('changed')->default(false);          // ¿tocó el interruptor a mano?
            $table->timestamp('changed_at')->nullable();         // cuándo se supo que lo cambió (o volvió a cambiar)
            $table->unsignedInteger('opens')->default(0);        // veces que abrió la pantalla de Brainy
            $table->unsignedInteger('care_taps')->default(0);    // botones de cuidado pulsados
            $table->timestamp('reported_at')->nullable();        // última vez que la app informó
            $table->timestamps();
            $table->unique(['user_id', 'experiment']);
            $table->index(['experiment', 'group']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('experiment_participants');
    }
};
