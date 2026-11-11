<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $t) {
            // Escalón elegido a mano (1–4); null = automático según nivel y uso del español.
            $t->unsignedTinyInteger('spanish_step')->nullable();
        });

        // Cuántas veces al día pidió el alumno español (traducción, ayuda, explicación).
        Schema::create('spanish_uses', function (Blueprint $t) {
            $t->id();
            $t->foreignId('user_id')->constrained()->cascadeOnDelete();
            $t->date('day');
            $t->string('kind', 20);
            $t->unsignedInteger('count')->default(0);
            $t->timestamps();
            $t->unique(['user_id', 'day', 'kind']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('spanish_uses');
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn('spanish_step'));
    }
};
