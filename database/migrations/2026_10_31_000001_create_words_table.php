<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('words', function (Blueprint $table) {
            $table->id();
            $table->string('word', 64)->unique();
            $table->unsignedInteger('rank')->index();          // posición por frecuencia (1 = más común)
            $table->string('source', 16)->default('starter');  // starter | ngsl
            $table->string('translation')->nullable();          // se llena con words:enrich
            $table->string('example')->nullable();              // la palabra va entre *asteriscos*
            $table->string('example_es')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('words');
    }
};
