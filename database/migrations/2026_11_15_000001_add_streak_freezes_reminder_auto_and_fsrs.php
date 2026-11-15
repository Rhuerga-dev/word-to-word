<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Solo añade columnas (no cambia ni borra datos):
 * - users.streak_freezes: protectores de racha (salvan un día sin estudiar).
 * - users.reminder_auto: el recordatorio llega a la hora en que sueles practicar.
 * - user_words.stability / difficulty / last_reviewed_on: memoria de cada palabra para FSRS.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedTinyInteger('streak_freezes')->default(1);
            $table->boolean('reminder_auto')->default(false);
        });
        Schema::table('user_words', function (Blueprint $table) {
            $table->float('stability')->nullable();
            $table->float('difficulty')->nullable();
            $table->date('last_reviewed_on')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['streak_freezes', 'reminder_auto']);
        });
        Schema::table('user_words', function (Blueprint $table) {
            $table->dropColumn(['stability', 'difficulty', 'last_reviewed_on']);
        });
    }
};
