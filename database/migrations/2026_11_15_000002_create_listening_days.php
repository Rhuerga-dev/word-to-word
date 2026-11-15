<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cómo entiende cada alumno al ESCUCHAR, por día: aciertos y fallos en el ejercicio de Oído
 * y cuántas veces pidió "repeat" o "slower". La escalera de español lo usa para subir o bajar.
 * Solo añade una tabla nueva.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('listening_days', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('day');
            $table->unsignedInteger('ear_ok')->default(0);
            $table->unsignedInteger('ear_fail')->default(0);
            $table->unsignedInteger('repeats')->default(0);
            $table->timestamps();
            $table->unique(['user_id', 'day']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('listening_days');
    }
};
