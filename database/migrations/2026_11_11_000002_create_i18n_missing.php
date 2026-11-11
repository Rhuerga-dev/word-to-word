<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Textos de la interfaz que una app pidió y aún no tienen traducción (los traduce i18n:translate).
        Schema::create('i18n_missing', function (Blueprint $table) {
            $table->id();
            $table->string('lang', 8);
            $table->string('hash', 64);
            $table->text('key');
            $table->unsignedInteger('hits')->default(1);
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->timestamps();
            $table->unique(['lang', 'hash']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('i18n_missing');
    }
};
