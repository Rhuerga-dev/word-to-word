<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_words', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('word_id')->constrained()->cascadeOnDelete();
            $table->unsignedTinyInteger('level')->default(0);
            $table->date('next_review')->nullable()->index();
            $table->date('introduced_at')->nullable();
            $table->unsignedSmallInteger('fails')->default(0);
            $table->unsignedSmallInteger('reviews')->default(0);
            $table->text('aid')->nullable();                         // escena AID del usuario
            $table->unsignedTinyInteger('best_pron_score')->nullable(); // 0-100
            $table->unsignedTinyInteger('last_pron_score')->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'word_id']);
        });

        Schema::create('study_days', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('day');
            $table->unsignedSmallInteger('new_count')->default(0);
            $table->unsignedSmallInteger('review_count')->default(0);
            $table->timestamps();
            $table->unique(['user_id', 'day']);
        });

        // Sonidos que el usuario pronuncia mal (para practicar después).
        Schema::create('phoneme_errors', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('phoneme', 16);
            $table->unsignedInteger('count')->default(0);
            $table->string('last_word', 64)->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'phoneme']);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->unsignedSmallInteger('daily_new')->default(10);
            $table->integer('day_offset')->default(0);       // solo para pruebas
            $table->unsignedInteger('streak')->default(0);
            $table->date('last_study_day')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['daily_new', 'day_offset', 'streak', 'last_study_day']);
        });
        Schema::dropIfExists('phoneme_errors');
        Schema::dropIfExists('study_days');
        Schema::dropIfExists('user_words');
    }
};
