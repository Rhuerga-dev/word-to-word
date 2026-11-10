<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Camino: avance de cada alumno en cada unidad.
        Schema::create('unit_progress', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('unit', 40);
            $table->timestamp('shadow_at')->nullable();     // shadowing de la unidad hecho
            $table->unsignedTinyInteger('test_score')->nullable();   // mejor nota de la prueba (0–10)
            $table->unsignedSmallInteger('test_tries')->default(0);
            $table->string('test_feedback', 600)->nullable();
            $table->timestamp('passed_at')->nullable();     // prueba aprobada = unidad completa
            $table->timestamps();
            $table->unique(['user_id', 'unit']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('unit_progress');
    }
};
