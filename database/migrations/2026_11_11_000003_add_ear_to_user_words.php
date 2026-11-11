<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Oído: reconocer la palabra al oírla, rápido y sin pasar por el español.
        Schema::table('user_words', function (Blueprint $table) {
            $table->unsignedTinyInteger('ear_level')->default(0);     // veces seguidas reconocida rápido (espaciadas)
            $table->date('ear_next')->nullable()->index();           // cuándo vuelve a sonar
            $table->unsignedInteger('ear_ms')->nullable();           // lo que tardaste la última vez
        });
    }

    public function down(): void
    {
        Schema::table('user_words', function (Blueprint $table) {
            $table->dropIndex(['ear_next']);
            $table->dropColumn(['ear_level', 'ear_next', 'ear_ms']);
        });
    }
};
