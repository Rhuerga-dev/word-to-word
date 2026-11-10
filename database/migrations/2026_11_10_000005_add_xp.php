<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Puntos (XP): una meta diaria que junta todo lo que se practica.
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedSmallInteger('xp_goal')->default(100);
            $table->unsignedInteger('xp_total')->default(0);
        });

        Schema::create('xp_days', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('day');
            $table->unsignedInteger('xp')->default(0);
            $table->json('by_source')->nullable();         // {"review": 30, "speak": 40, ...}
            $table->unsignedTinyInteger('sessions')->default(0);  // sesiones guiadas terminadas ese día
            $table->timestamps();
            $table->unique(['user_id', 'day']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('xp_days');
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn(['xp_goal', 'xp_total']));
    }
};
