<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedSmallInteger('speaking_goal')->default(5);  // minutos de tu voz por día (solo el tiempo hablando)
        });

        // Cada conversación por voz: cuánto hablaste, a qué ritmo y con cuántas pausas largas.
        Schema::create('speaking_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('scenario', 40)->default('free');
            $table->date('day');                                   // día de estudio del alumno
            $table->unsignedInteger('turns')->default(0);
            $table->unsignedInteger('words')->default(0);
            $table->unsignedInteger('speech_ms')->default(0);     // tiempo hablando (sin silencios de antes y después)
            $table->unsignedInteger('long_pauses')->default(0);   // pausas de 0,7 s o más en medio de una frase
            $table->timestamp('ended_at')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'day']);
        });

        // Errores al hablar: se repasan como las palabras (diciendo la frase correcta en voz alta).
        Schema::create('speaking_mistakes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('speaking_session_id')->nullable()->constrained()->nullOnDelete();
            $table->string('said', 300);
            $table->string('correct', 300);
            $table->string('why', 300)->nullable();
            $table->unsignedTinyInteger('stage')->default(0);     // repasos aprobados seguidos (5 = dominado)
            $table->unsignedInteger('reviews')->default(0);
            $table->date('reviewed_on')->nullable();
            $table->date('next_review');
            $table->date('mastered_on')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'next_review']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('speaking_mistakes');
        Schema::dropIfExists('speaking_sessions');
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('speaking_goal'));
    }
};
