<?php

namespace Tests\Feature;

use App\Models\Course;
use App\Models\User;
use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** `courses:load`: crea un curso y carga sus palabras preparadas, sin tocar los demás cursos. */
class LoadCourseTest extends TestCase
{
    use RefreshDatabase;

    private string $dir;

    protected function setUp(): void
    {
        parent::setUp();
        $this->dir = storage_path('framework/testing/course-'.uniqid());
        File::ensureDirectoryExists($this->dir);
        Word::create(['word' => 'pie', 'rank' => 1, 'source' => 'ngsl', 'translation' => 'tarta', 'example' => 'Apple *pie*.']);
    }

    protected function tearDown(): void
    {
        File::deleteDirectory($this->dir);
        parent::tearDown();
    }

    private function save(array $rows, string $name = 'part0.json'): void
    {
        File::put("{$this->dir}/{$name}", json_encode($rows));
    }

    private function row(string $word, int $rank, array $over = []): array
    {
        return $over + ['word' => $word, 'rank' => $rank, 'source' => 'starter', 'translation' => "t-$word", 'example' => "Un *$word*.", 'definition' => 'd'];
    }

    public function test_it_creates_the_course_switched_off_and_loads_its_words_apart_from_the_others(): void
    {
        $this->save([$this->row('pie', 1, ['translation' => 'foot']), $this->row('casa', 2)]);

        $this->artisan('courses:load', ['code' => 'es-en', '--path' => $this->dir])->assertExitCode(0);

        $course = Course::where('code', 'es-en')->sole();
        $this->assertSame(['es', 'en', 'es-US', false], [$course->learn, $course->from, $course->speech_locale, $course->active]);
        $this->assertSame(['casa' => 't-casa', 'pie' => 'foot'], $course->words()->orderBy('word')->pluck('translation', 'word')->all());
        // El curso de siempre sigue con lo suyo, y un alumno de inglés no ve nada nuevo.
        $this->assertSame(['pie' => 'tarta'], Word::pluck('translation', 'word')->all());
        Sanctum::actingAs(User::factory()->create(['cefr_level' => 'A1']));
        $this->assertStringNotContainsString('t-casa', $this->getJson('/api/today')->assertOk()->getContent());
    }

    public function test_running_it_again_updates_instead_of_duplicating(): void
    {
        $this->save([$this->row('casa', 2)]);
        $this->artisan('courses:load', ['code' => 'es-en', '--path' => $this->dir])->assertExitCode(0);
        $this->save([$this->row('casa', 2, ['translation' => 'house; home']), $this->row('día', 3)]);
        $this->artisan('courses:load', ['code' => 'es-en', '--path' => $this->dir])->assertExitCode(0);

        $this->assertSame(1, Course::where('code', 'es-en')->count());
        $this->assertSame(['casa' => 'house; home', 'día' => 't-día'], DB::table('words')->where('course_id', '!=', 1)->orderBy('word')->pluck('translation', 'word')->all());
    }

    public function test_badly_written_rows_are_skipped_and_reported_and_a_dry_run_saves_nothing(): void
    {
        $this->save([
            $this->row('casa', 2),
            $this->row('sin', 3, ['example' => 'Sin asteriscos.']),
            $this->row('vacia', 4, ['translation' => '']),
            ['word' => 'sinorden', 'translation' => 'x', 'example' => '*x*'],
        ]);

        $this->artisan('courses:load', ['code' => 'es-en', '--path' => $this->dir, '--dry-run' => true])->assertExitCode(1);
        $this->assertSame(0, Course::where('code', 'es-en')->count());

        $this->artisan('courses:load', ['code' => 'es-en', '--path' => $this->dir])->assertExitCode(0);
        $this->assertSame(['casa'], DB::table('words')->where('course_id', '!=', 1)->pluck('word')->all());
    }

    public function test_only_courses_from_the_fixed_list_can_be_loaded(): void
    {
        $this->save([$this->row('casa', 2)]);

        $this->artisan('courses:load', ['code' => 'xx-yy', '--path' => $this->dir])->assertExitCode(1);
        $this->assertSame(1, Course::count());
    }

    public function test_the_prepared_spanish_words_are_well_written(): void
    {
        // El contenido de verdad del repositorio: todas las fichas completas y sin repetir.
        $seen = [];
        foreach (File::glob(database_path('content/courses/es-en/words/*.json')) as $file) {
            foreach (json_decode(File::get($file), true) as $row) {
                $this->assertNull(\App\Console\Commands\LoadCourse::problem($row), ($row['word'] ?? '?').' en '.basename($file));
                foreach (['example_es', 'definition', 'gloss', 'emoji', 'definition_easy', 'phrase', 'sentence_long'] as $key) {
                    $this->assertNotEmpty($row[$key] ?? '', "{$row['word']}: falta {$key}");
                }
                $this->assertArrayNotHasKey($row['word'], $seen, "{$row['word']} está repetida");
                $seen[$row['word']] = true;
            }
        }
        $this->assertGreaterThanOrEqual(60, count($seen));
    }
}
