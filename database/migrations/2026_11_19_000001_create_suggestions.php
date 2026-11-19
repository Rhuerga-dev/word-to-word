<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Sugerencias de los alumnos (ideas, fallos, otros). Solo añade una tabla nueva.
 * Se borran con la cuenta (cascade). «Reiniciar progreso» no las toca.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('suggestions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('type', 10);                    // idea | bug | other
            $table->text('message');
            $table->string('app_version', 30)->nullable();
            $table->string('platform', 10)->nullable();    // android | ios | web
            $table->string('screen', 60)->nullable();      // desde qué pantalla se envió
            $table->string('status', 12)->default('new');  // new | reviewing | done | dismissed
            $table->timestamps();
            $table->index(['status', 'created_at']);
            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('suggestions');
    }
};
