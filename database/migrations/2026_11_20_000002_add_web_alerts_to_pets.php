<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Avisos de Brainy en la web (notificación push del servidor; la app los programa en el teléfono).
 * Solo añade columnas a `pets`:
 *  - web_alerts: el alumno los activó en la web (Ajustes → Brainy).
 *  - web_alerted_at: cuándo fue el último aviso (no insistir: 3 h de separación y uno por ausencia).
 *  - web_alerts_today: cuántos lleva ese día (máximo 2).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pets', function (Blueprint $table) {
            $table->boolean('web_alerts')->default(false);
            $table->dateTime('web_alerted_at')->nullable();
            $table->unsignedTinyInteger('web_alerts_today')->default(0);
        });
    }

    public function down(): void
    {
        Schema::table('pets', function (Blueprint $table) {
            $table->dropColumn(['web_alerts', 'web_alerted_at', 'web_alerts_today']);
        });
    }
};
