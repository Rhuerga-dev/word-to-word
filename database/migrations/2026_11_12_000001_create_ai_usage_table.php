<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Cada llamada que cuesta dinero (Claude, Azure Speech): quién, qué y cuánto, para saber el coste por alumno. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ai_usage', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->index();   // null = tareas del servidor (palabras, traducciones…)
            $table->date('day')->index();
            $table->string('provider', 16);                        // claude | azure
            $table->string('kind', 32);                            // converse, narration, transcribe, assess, tts…
            $table->unsignedInteger('input_tokens')->default(0);
            $table->unsignedInteger('output_tokens')->default(0);
            $table->unsignedInteger('audio_ms')->default(0);
            $table->unsignedInteger('chars')->default(0);
            $table->decimal('cost_usd', 10, 6)->default(0);
            $table->timestamp('created_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_usage');
    }
};
