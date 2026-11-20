<?php

namespace Tests\Feature;

use App\Models\Course;
use App\Models\User;
use App\Models\Word;
use App\Support\CurrentCourse;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Cursos (paso 2b): cada alumno solo ve las palabras de SU curso, en toda la app y sin que cada pantalla
 * tenga que acordarse de filtrar (regla global de `Word` + `CurrentCourse`).
 */
class CourseScopeTest extends TestCase
{
    use RefreshDatabase;

    private Course $spanish;

    private User $student;

    protected function setUp(): void
    {
        parent::setUp();
        $this->spanish = Course::create(['code' => 'es-en', 'learn' => 'es', 'from' => 'en', 'name' => 'Spanish for English speakers', 'speech_locale' => 'es-US', 'active' => false]);
        // Curso de inglés: 12 palabras listas. Curso de español: dos, con nombres que no se confunden con nada.
        foreach (range(1, 12) as $i) {
            $this->word("english$i", $i);
        }
        $this->word('zzperro', 1, $this->spanish->id);
        $this->word('zzgato', 2, $this->spanish->id);
        $this->student = User::factory()->create(['cefr_level' => 'A1']);
    }

    private function word(string $text, int $rank, ?int $course = null): Word
    {
        return Word::create(['word' => $text, 'rank' => $rank, 'source' => 'ngsl', 'category' => 'animals', 'translation' => "t-$text",
            'example' => "An example with *$text*.", 'example_es' => 'Un ejemplo.', 'definition' => "meaning of $text"] + ($course ? ['course_id' => $course] : []));
    }

    private function spanishId(string $text): int
    {
        return (int) DB::table('words')->where('word', $text)->value('id');
    }

    public function test_an_english_student_never_sees_words_from_another_course_on_any_screen(): void
    {
        Sanctum::actingAs($this->student);
        // Que tenga algo aprendido: Oído y los repasos solo salen con palabras ya vistas.
        foreach (Word::orderBy('rank')->limit(3)->get() as $w) {
            $this->postJson("/api/words/{$w->id}/learn")->assertOk();
        }

        $seen = 0;
        foreach (['/today', '/session/today', '/stats', '/families', '/ear', '/levels', '/levels/placement', '/path', '/progress', '/pet', '/me'] as $path) {
            $r = $this->getJson('/api'.$path);
            $this->assertLessThan(500, $r->getStatusCode(), "$path falló");
            $this->assertStringNotContainsString('zzperro', $r->getContent(), "$path enseña una palabra de otro curso");
            $this->assertStringNotContainsString('zzgato', $r->getContent(), "$path enseña una palabra de otro curso");
            $seen += substr_count($r->getContent(), 'english');
        }
        $this->assertGreaterThan(0, $seen, 'las de su curso sí salen');
    }

    public function test_a_word_from_another_course_cannot_be_learned_reviewed_or_heard_by_its_id(): void
    {
        Sanctum::actingAs($this->student);
        $id = $this->spanishId('zzperro');

        $this->postJson("/api/words/$id/learn")->assertNotFound();
        $this->postJson("/api/words/$id/review", ['grade' => 'good'])->assertNotFound();
        $this->putJson("/api/words/$id/aid", ['aid' => 'x'])->assertNotFound();
        $this->assertSame(0, DB::table('user_words')->where('word_id', $id)->count());
    }

    public function test_adding_your_own_word_keeps_it_in_your_course(): void
    {
        Word::withoutGlobalScope('course')->where('word', 'zzgato')->update(['word' => 'pie']);   // «pie» ya existe en español
        Sanctum::actingAs($this->student);

        $this->postJson('/api/words/personal', ['word' => 'pie', 'translation' => 'tarta', 'example' => 'I love apple pie.'])->assertSuccessful();

        $rows = DB::table('words')->where('word', 'pie')->orderBy('course_id')->pluck('translation', 'course_id')->all();
        $this->assertSame([Course::DEFAULT_ID => 'tarta', $this->spanish->id => 't-zzgato'], $rows);
    }

    public function test_a_student_of_the_other_course_sees_only_that_course(): void
    {
        $this->student->forceFill(['course_id' => $this->spanish->id])->save();
        Sanctum::actingAs($this->student->fresh());

        $this->assertEqualsCanonicalizing(['zzperro', 'zzgato'], Word::pluck('word')->all());
        $this->postJson('/api/words/'.$this->spanishId('zzperro').'/learn')->assertOk();
        $english = (int) DB::table('words')->where('word', 'english1')->value('id');
        $this->postJson("/api/words/$english/learn")->assertNotFound();
    }

    public function test_pronunciation_is_scored_in_the_language_of_the_course(): void
    {
        config(['vocab.azure_speech.key' => 'test-key', 'vocab.azure_speech.region' => 'eastus']);
        \Illuminate\Support\Facades\Http::fake(['*' => \Illuminate\Support\Facades\Http::response(['RecognitionStatus' => 'Success', 'NBest' => [[
            'Lexical' => 'hola', 'PronunciationAssessment' => ['AccuracyScore' => 90, 'FluencyScore' => 90, 'CompletenessScore' => 100, 'PronScore' => 90], 'Words' => [],
        ]]])]);
        $pron = app(\App\Services\PronunciationService::class);
        $languages = fn () => collect(\Illuminate\Support\Facades\Http::recorded())->map(fn ($pair) => \Illuminate\Support\Str::match('/language=([A-Za-z-]+)/', $pair[0]->url()))->all();

        Sanctum::actingAs($this->student);                                   // inglés: como siempre
        $pron->assess(str_repeat("\0", 2000), 'hello');
        $this->assertSame(['en-US'], $languages());

        $this->student->forceFill(['course_id' => $this->spanish->id])->save();
        Sanctum::actingAs($this->student->fresh());                          // español: se evalúa en español
        $pron->assess(str_repeat("\0", 2000), 'hola');
        $pron->azureTranscribe(str_repeat("\0", 2000));
        $this->assertSame(['en-US', 'es-US', 'es-US'], $languages());
    }

    public function test_the_voice_reads_slower_the_language_you_are_learning_whatever_it_is(): void
    {
        config(['vocab.azure_speech.key' => 'test-key', 'vocab.azure_speech.region' => 'eastus', 'vocab.tts.local_url' => null, 'vocab.tts.enabled' => true]);
        \Illuminate\Support\Facades\Storage::fake('local');
        \Illuminate\Support\Facades\Http::fake(['*' => \Illuminate\Support\Facades\Http::response('mp3')]);
        $tts = app(\App\Services\TtsService::class);
        $said = fn () => collect(\Illuminate\Support\Facades\Http::recorded())
            ->map(fn ($pair) => \Illuminate\Support\Str::match('/name="([a-z]{2})-/', $pair[0]->body()).' '.\Illuminate\Support\Str::match('/rate="([^"]+)"/', $pair[0]->body()))->all();

        Sanctum::actingAs($this->student);                                   // aprende inglés (como siempre)
        $tts->audio('house', 'en');
        $tts->audio('casa', 'es');
        $tts->audio('house', 'en', slow: true);
        $this->assertSame(['en -5%', 'es 0%', 'en -30%'], $said());

        $this->student->forceFill(['course_id' => $this->spanish->id])->save();
        Sanctum::actingAs($this->student->fresh());                          // aprende español: al revés
        $tts->audio('perro', 'es');
        $tts->audio('dog', 'en');
        $tts->audio('perro', 'es', slow: true);
        $this->assertSame(['es -5%', 'en 0%', 'es -30%'], array_slice($said(), 3));
    }

    public function test_each_course_brings_its_own_content_and_inherits_the_rest(): void
    {
        // El paquete del curso de español solo cambia las conversaciones; lo demás lo hereda.
        config(['courses.es-en' => ['speaking' => ['scenarios' => [
            'cafe' => ['title' => 'At the café', 'emoji' => '☕', 'desc' => 'Order a coffee in Spanish.', 'role' => 'Eres un camarero amable.'],
        ]]]]);
        $titles = fn () => collect($this->getJson('/api/speaking/scenarios')->assertOk()->json('scenarios'))->pluck('title')->all();

        Sanctum::actingAs($this->student);                                   // inglés: las de siempre
        $english = $titles();
        $this->assertContains('Charla libre', $english);
        $this->assertNotContains('At the café', $english);
        $this->assertSame(config('speaking.scenarios.free.role'), \App\Support\CoursePack::get('speaking.scenarios.free.role'));

        $this->student->forceFill(['course_id' => $this->spanish->id])->save();
        Sanctum::actingAs($this->student->fresh());                          // español: las suyas
        $this->assertSame(['At the café'], $titles());
        $this->assertSame('Eres un camarero amable.', \App\Support\CoursePack::get('speaking.scenarios.cafe.role'));
        // Lo que su paquete no trae, lo hereda del de siempre; y las reglas del motor no dependen del curso.
        $this->assertSame(config('speaking.picture_themes'), \App\Support\CoursePack::get('speaking.picture_themes'));
        $this->assertSame('x', \App\Support\CoursePack::get('speaking.no_existe', 'x'));
    }

    public function test_a_course_that_brings_its_own_list_does_not_inherit_items_from_the_english_one(): void
    {
        config(['courses.es-en' => ['units' => ['levels' => []]], 'units.levels' => ['A1' => [['id' => 'hello', 'title' => 'Saludar', 'words' => ['english1'], 'sound' => 'θ', 'scenario' => 'free']]]]);
        $this->student->forceFill(['course_id' => $this->spanish->id])->save();
        Sanctum::actingAs($this->student->fresh());

        $this->assertSame([], \App\Support\CoursePack::get('units.levels', []));
        $this->assertSame([], \App\Support\CoursePack::get('units.levels.A1', []), 'no hereda las unidades de inglés');
        $this->assertStringNotContainsString('Saludar', $this->getJson('/api/path')->assertOk()->getContent());
        // Y la pantalla va en el idioma del alumno (inglés), no en español.
        $this->assertSame('en', $this->getJson('/api/me')->json('spanish.ui'));

        $this->student->forceFill(['course_id' => Course::DEFAULT_ID])->save();
        Sanctum::actingAs($this->student->fresh());
        $this->assertStringContainsString('Saludar', $this->getJson('/api/path')->assertOk()->getContent());
        $this->assertSame('es', $this->getJson('/api/me')->json('spanish.ui'));
    }

    public function test_content_is_always_read_through_the_course_pack(): void
    {
        // Regla para el futuro: el contenido no se pide con config() a secas (se saltaría el curso).
        $content = 'speaking\\.(scenarios|narration_topics|shadowing_themes|picture_themes|mistake_categories|shadowing_bank)|units\\.levels|professions\\.(list|replace|goals)';
        $bad = [];
        foreach (\Illuminate\Support\Facades\File::allFiles(app_path()) as $file) {
            if ($file->getFilename() === 'CoursePack.php') {
                continue;
            }
            if (preg_match_all('/(?<![\\w>:\\\\])config\\([\'"]('.$content.')/', $file->getContents(), $m)) {
                $bad[] = $file->getRelativePathname().': '.implode(', ', $m[1]);
            }
        }
        $this->assertSame([], $bad, 'Usa CoursePack::get() para leer contenido');
    }

    public function test_an_app_that_knows_nothing_about_courses_still_gets_the_right_voice(): void
    {
        config(['vocab.azure_speech.key' => 'test-key', 'vocab.azure_speech.region' => 'eastus', 'vocab.tts.local_url' => null, 'vocab.tts.enabled' => true]);
        \Illuminate\Support\Facades\Storage::fake('local');
        \Illuminate\Support\Facades\Http::fake(['*' => \Illuminate\Support\Facades\Http::response('mp3')]);
        $voices = fn () => collect(\Illuminate\Support\Facades\Http::recorded())->map(fn ($pair) => \Illuminate\Support\Str::match('/name="([a-z]{2})-/', $pair[0]->body()))->all();

        Sanctum::actingAs($this->student);                                   // curso de inglés: «en» es inglés, como siempre
        $this->get('/api/tts?text=house&lang=en')->assertOk();
        $this->get('/api/tts?text=casa&lang=es')->assertOk();

        $this->student->forceFill(['course_id' => $this->spanish->id])->save();
        Sanctum::actingAs($this->student->fresh());                          // curso de español: «en» = lo que aprendo = español
        $this->get('/api/tts?text=perro&lang=en')->assertOk();
        $this->get('/api/tts?text=dog&lang=es')->assertOk();

        $this->assertSame(['en', 'es', 'es', 'en'], $voices());
        $this->assertSame('en-US', app(\App\Support\CurrentCourse::class)->nativeLocale());
    }

    public function test_progress_is_kept_apart_for_each_course_and_nothing_is_lost_when_switching(): void
    {
        Sanctum::actingAs($this->student);
        foreach (Word::orderBy('rank')->limit(3)->get() as $w) {
            $this->postJson("/api/words/{$w->id}/learn")->assertOk();          // 3 palabras de inglés aprendidas
        }
        $this->assertSame(3, $this->getJson('/api/stats')->assertOk()->json('learned'));

        $this->student->forceFill(['course_id' => $this->spanish->id])->save();
        Sanctum::actingAs($this->student->fresh());                           // se pasa al curso de español: empieza de cero
        $this->assertSame(0, $this->getJson('/api/stats')->assertOk()->json('learned'));
        $this->postJson('/api/words/'.$this->spanishId('zzperro').'/learn')->assertOk();
        $this->assertSame(1, $this->getJson('/api/stats')->json('learned'));

        $this->student->forceFill(['course_id' => Course::DEFAULT_ID])->save();
        Sanctum::actingAs($this->student->fresh());                           // vuelve a inglés: su progreso sigue ahí
        $this->assertSame(3, $this->getJson('/api/stats')->json('learned'));
        $this->assertSame(4, DB::table('user_words')->where('user_id', $this->student->id)->count());
    }

    public function test_resetting_progress_erases_every_course(): void
    {
        Sanctum::actingAs($this->student);
        $this->postJson('/api/words/'.Word::orderBy('rank')->value('id').'/learn')->assertOk();
        DB::table('user_words')->insert(['user_id' => $this->student->id, 'word_id' => $this->spanishId('zzperro'), 'level' => 1, 'introduced_at' => now(), 'created_at' => now(), 'updated_at' => now()]);

        $route = collect(app('router')->getRoutes())->first(fn ($r) => str_contains($r->getActionName(), 'StudyController@reset'));
        $this->assertNotNull($route, 'no encuentro la ruta de reiniciar progreso');
        $this->json($route->methods()[0], '/'.$route->uri(), ['password' => 'password'])->assertSuccessful();   // la de fábrica de los tests

        $this->assertSame(0, DB::table('user_words')->where('user_id', $this->student->id)->count());
    }

    public function test_the_spanish_course_has_its_own_shadowing_texts_and_only_speaking_modes_that_work(): void
    {
        // Con el paquete de verdad del curso de español (config/courses.php) y su banco de textos.
        $bank = json_decode(file_get_contents(database_path('content/courses/es-en/shadowing.json')), true);
        $this->assertSame(config('speaking.shadowing_themes'), array_keys($bank['A1']), 'un texto por cada tema, para no caer en la IA');
        $this->student->forceFill(['course_id' => $this->spanish->id])->save();
        Sanctum::actingAs($this->student->fresh());
        \Illuminate\Support\Facades\Http::fake();   // si pidiera el texto a la IA, se vería aquí

        foreach (range(0, 11) as $skip) {
            $text = $this->getJson("/api/speaking/shadowing?skip=$skip")->assertOk()->json();
            $this->assertCount(5, $text['sentences'], $text['theme']);
            foreach ($text['sentences'] as $sentence) {
                $this->assertMatchesRegularExpression(\App\Services\ShadowingBank::SENTENCE_ANY, $sentence);
            }
        }
        \Illuminate\Support\Facades\Http::assertNothingSent();
        $this->assertStringContainsString('¿', json_encode($bank, JSON_UNESCAPED_UNICODE), 'frases en español de verdad');
        $this->assertSame('shadowing', $this->getJson('/api/session/today')->assertOk()->json('plan.speak'));

        // El curso de inglés sigue con sus textos y sus tres formas de hablar.
        $this->student->forceFill(['course_id' => Course::DEFAULT_ID])->save();
        Sanctum::actingAs($this->student->fresh());
        $english = $this->getJson('/api/speaking/shadowing')->assertOk()->json('sentences.0');
        $this->assertMatchesRegularExpression(\App\Services\ShadowingBank::SENTENCE, $english);
        $this->assertContains($this->getJson('/api/session/today')->json('plan.speak'), \App\Http\Controllers\Api\SessionController::SPEAK_MODES);
    }

    public function test_pronunciation_accepts_spanish_sentences_only_in_the_spanish_course(): void
    {
        config(['vocab.azure_speech.key' => 'test-key', 'vocab.azure_speech.region' => 'eastus']);
        \Illuminate\Support\Facades\Http::fake(['*' => \Illuminate\Support\Facades\Http::response(['RecognitionStatus' => 'Success', 'NBest' => [[
            'Lexical' => 'como estas', 'PronunciationAssessment' => ['AccuracyScore' => 90, 'FluencyScore' => 90, 'CompletenessScore' => 100, 'PronScore' => 90], 'Words' => [],
        ]]])]);
        $send = fn (string $text) => $this->post('/api/pronunciation/assess', ['text' => $text,
            'audio' => \Illuminate\Http\UploadedFile::fake()->createWithContent('voz.wav', str_repeat("\0", 2000))], ['Accept' => 'application/json'])->getStatusCode();

        Sanctum::actingAs($this->student);                                   // curso de inglés: como siempre, sin acentos
        $this->assertSame(422, $send('¿Cómo estás?'));
        $this->assertNotSame(422, $send('How are you?'));

        $this->student->forceFill(['course_id' => $this->spanish->id])->save();
        Sanctum::actingAs($this->student->fresh());                          // curso de español: acentos, ñ, ¿ y ¡
        $this->assertNotSame(422, $send('¿Cómo estás?'));
        $this->assertNotSame(422, $send('Mañana voy al médico.'));
        $this->assertSame(422, $send('<script>alert(1)</script>'));
    }

    public function test_without_a_student_the_course_is_the_first_one_and_a_task_can_choose_another(): void
    {
        $current = app(CurrentCourse::class);

        $this->assertSame(Course::DEFAULT_ID, $current->id());
        $this->assertSame(12, Word::count());                               // comandos y tareas: el curso de siempre
        $inside = $current->run($this->spanish->id, fn () => [Word::count(), Word::create(['word' => 'zzpez', 'rank' => 3, 'source' => 'ngsl'])->course_id]);
        $this->assertSame([2, $this->spanish->id], $inside);                // dentro: el otro curso, también al crear
        $this->assertSame(Course::DEFAULT_ID, $current->id());              // al salir vuelve el de antes
        $this->assertSame(15, Word::withoutGlobalScope('course')->count());
    }
}
