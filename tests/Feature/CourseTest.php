<?php

namespace Tests\Feature;

use App\Models\Course;
use App\Models\User;
use App\Models\Word;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Cursos (paso 2a): W2W es un núcleo y el idioma es un dato. Con un solo curso, nada cambia para el alumno.
 */
class CourseTest extends TestCase
{
    use RefreshDatabase;

    public function test_w2w_is_born_with_one_course_english_for_spanish_speakers(): void
    {
        $course = Course::sole();

        $this->assertSame(Course::DEFAULT_ID, $course->id);
        $this->assertSame(['en-es', 'en', 'es', 'en-US', true], [$course->code, $course->learn, $course->from, $course->speech_locale, $course->active]);
    }

    public function test_words_and_users_belong_to_the_first_course_without_saying_it(): void
    {
        // El código de siempre no sabe de cursos: lo que cree cae en el curso de siempre.
        $word = Word::create(['word' => 'house', 'rank' => 1, 'source' => 'ngsl'])->fresh();
        $user = User::factory()->create()->fresh();

        $this->assertSame(Course::DEFAULT_ID, (int) $word->course_id);
        $this->assertSame('en-es', $word->course->code);
        $this->assertSame(Course::DEFAULT_ID, (int) $user->course_id);
        $this->assertSame('en-es', $user->course->code);
        $this->assertSame(1, Course::find(1)->words()->count());
    }

    public function test_the_same_word_can_live_in_two_courses_but_only_once_in_each(): void
    {
        $spanish = Course::create(['code' => 'es-en', 'learn' => 'es', 'from' => 'en', 'name' => 'Spanish for English speakers', 'speech_locale' => 'es-US', 'active' => false]);
        Word::create(['word' => 'pie', 'rank' => 1, 'source' => 'ngsl']);                               // «tarta», en inglés
        Word::create(['word' => 'pie', 'rank' => 1, 'source' => 'ngsl', 'course_id' => $spanish->id]);  // «foot», en español

        $this->assertSame(2, Word::withoutGlobalScope('course')->where('word', 'pie')->count());
        $this->assertSame(1, Word::where('word', 'pie')->count(), 'una búsqueda normal solo ve la del curso actual');
        $this->assertSame(1, $spanish->words()->count());

        $this->expectException(QueryException::class);
        Word::create(['word' => 'pie', 'rank' => 2, 'source' => 'ngsl']);                               // repetida en su curso: no
    }

    public function test_a_student_cannot_change_course_by_sending_it_in_the_profile_or_settings(): void
    {
        Course::create(['code' => 'es-en', 'learn' => 'es', 'from' => 'en', 'name' => 'Spanish', 'speech_locale' => 'es-US', 'active' => false]);
        $user = User::factory()->create(['cefr_level' => 'B1']);
        Sanctum::actingAs($user);

        $this->putJson('/api/profile', ['profession' => 'developer', 'course_id' => 2]);
        $this->putJson('/api/settings', ['daily_new' => 5, 'course_id' => 2]);
        $user->fill(['course_id' => 2])->save();

        $this->assertSame(Course::DEFAULT_ID, (int) DB::table('users')->where('id', $user->id)->value('course_id'));
    }

    public function test_the_course_migration_can_be_undone(): void
    {
        Word::create(['word' => 'house', 'rank' => 1, 'source' => 'ngsl']);
        $this->artisan('migrate:rollback', ['--path' => 'database/migrations/2026_11_20_000001_create_courses.php'])->assertExitCode(0);

        $this->assertFalse(\Illuminate\Support\Facades\Schema::hasTable('courses'));
        $this->assertFalse(\Illuminate\Support\Facades\Schema::hasColumn('words', 'course_id'));
        $this->assertSame(1, DB::table('words')->where('word', 'house')->count(), 'deshacer no borra palabras');

        $this->artisan('migrate', ['--path' => 'database/migrations/2026_11_20_000001_create_courses.php'])->assertExitCode(0);
        $this->assertSame(1, (int) DB::table('words')->where('word', 'house')->value('course_id'));
    }
}
