<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Registro solo con código de invitación (regla de Huerga Labs). Solo añade:
 * - invitation_codes: el código, cuántos usos tiene y cuántos se gastaron, caducidad y nota.
 * - users.invitation_code_id: con qué código entró cada alumno.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('invitation_codes', function (Blueprint $table) {
            $table->id();
            $table->string('code', 24)->unique();
            $table->unsignedInteger('max_uses')->default(1);
            $table->unsignedInteger('used')->default(0);
            $table->timestamp('expires_at')->nullable();
            $table->boolean('active')->default(true);
            $table->string('note', 120)->nullable();
            $table->timestamps();
        });
        Schema::table('users', function (Blueprint $table) {
            $table->foreignId('invitation_code_id')->nullable()->constrained('invitation_codes')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropConstrainedForeignId('invitation_code_id');
        });
        Schema::dropIfExists('invitation_codes');
    }
};
