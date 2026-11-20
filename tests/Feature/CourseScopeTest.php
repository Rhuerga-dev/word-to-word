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
