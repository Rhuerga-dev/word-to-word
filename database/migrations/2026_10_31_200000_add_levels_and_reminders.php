<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Nivel MCER actual (A1..C1). null = todavía no hizo la prueba de nivel.
            $table->string('cefr_level', 2)->nullable();
            // Incluir el paquete de vocabulario para hablar con clientes.
            $table->boolean('freelance_pack')->default(true);

            // Recordatorio diario por notificación push.
            $table->boolean('reminder_enabled')->default(false);
            $table->string('reminder_time', 5)->default('19:00');      // HH:MM en la zona del usuario
            $table->string('timezone', 64)->default('America/New_York');
            $table->date('last_reminded_on')->nullable();
        });

        // Historial de pruebas de nivel y exámenes para subir de nivel.
        Schema::create('level_results', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('kind', 16);            // placement | exam
            $table->string('level', 2);            // nivel evaluado (o asignado en la prueba inicial)
            $table->unsignedTinyInteger('score');  // 0-100
            $table->boolean('passed');
            $table->string('new_level', 2)->nullable();
            $table->timestamps();
            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('level_results');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'cefr_level', 'freelance_pack', 'reminder_enabled',
                'reminder_time', 'timezone', 'last_reminded_on',
            ]);
        });
    }
};
