<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('achievements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('code', 40);
            $table->timestamp('unlocked_at');
            $table->boolean('seen')->default(false);   // ya se mostró el aviso
            $table->unique(['user_id', 'code']);
        });

        // Liga semanal: cada alumno decide si aparece (solo nombre e inicial).
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('league_visible')->default(true);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('achievements');
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('league_visible'));
    }
};
