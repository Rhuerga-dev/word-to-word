<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * W2W pasa a ser un núcleo con cursos (paso 2a). Un curso = el idioma que aprendes + el que ya hablas.
 *
 * - `courses`: la lista de cursos. Nace con uno solo, el de siempre: inglés para hispanohablantes (id 1).
 * - `words.course_id`: de qué curso es cada palabra. Todas las que hay pasan al curso 1.
 * - `users.course_id`: el curso que estudia cada alumno. Todos pasan al curso 1.
 * - La misma palabra puede existir en dos cursos («pie» en inglés y en español): la palabra ya no es única
 *   en toda la tabla, sino dentro de su curso.
 *
 * No borra ni cambia ningún dato: solo añade. Con un solo curso, la app se comporta exactamente igual.
 * (Sin clave foránea en la base de datos: SQLite no deja añadirla a una tabla que ya existe con valor por
 * defecto. La relación la cuida el código.)
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('courses', function (Blueprint $table) {
            $table->id();
            $table->string('code', 12)->unique();       // 'en-es' = aprender inglés hablando español
            $table->string('learn', 5);                 // idioma que se aprende (en, es…)
            $table->string('from', 5);                  // idioma del alumno
            $table->string('name', 80);                 // cómo se enseña en la lista
            $table->string('speech_locale', 10);        // voz y reconocimiento del idioma que se aprende (en-US…)
            $table->boolean('active')->default(true);   // false = aún no se ofrece a los alumnos
            $table->timestamps();
        });

        $now = now();
        DB::table('courses')->insert([
            'id' => 1, 'code' => 'en-es', 'learn' => 'en', 'from' => 'es', 'name' => 'Inglés para hispanohablantes',
            'speech_locale' => 'en-US', 'active' => true, 'created_at' => $now, 'updated_at' => $now,
        ]);

        Schema::table('words', function (Blueprint $table) {
            $table->unsignedBigInteger('course_id')->default(1);
        });
        Schema::table('words', function (Blueprint $table) {
            $table->dropUnique('words_word_unique');
            $table->unique(['course_id', 'word']);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->unsignedBigInteger('course_id')->default(1);
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('course_id');
        });
        Schema::table('words', function (Blueprint $table) {
            $table->dropUnique(['course_id', 'word']);
        });
        Schema::table('words', function (Blueprint $table) {
            $table->dropColumn('course_id');
            $table->unique('word');
        });
        Schema::dropIfExists('courses');
    }
};
