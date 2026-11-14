<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LevelTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Niveles pequeños para probar: 10 palabras cada uno.
        config([
            'vocab.levels' => [
                'A1' => ['name' => 'Básico', 'from' => 1, 'to' => 10, 'can' => ['a']],
                'A2' => ['name' => 'Elemental', 'from' => 11, 'to' => 20, 'can' => ['b']],
                'B1' => ['name' => 'Intermedio', 'from' => 21, 'to' => 30, 'can' => ['c']],
            ],
            'vocab.placement_per_level' => 4,
            'vocab.placement_pass' => 0.7,
            'vocab.level_exam_size' => 10,
            'vocab.level_exam_coverage' => 0.8,
            'vocab.level_exam_pass' => 0.8,
        ]);

        // Paquete de freelance con ranks bajos (como lo deja FreelanceWordSeeder).
        foreach (['scope', 'deadline', 'invoice'] as $i => $w) {
            Word::create(['word' => $w, 'rank' => $i + 1, 'source' => 'freelance',
                'translation' => "tr-$w", 'example' => "The *$w*.", 'example_es' => 'x']);
        }
        // 30 palabras generales: posiciones 1..30 => ranks 4..33.
        for ($i = 1; $i <= 30; $i++) {
            Word::create(['word' => "word$i", 'rank' => $i + 3, 'source' => 'ngsl',
                'translation' => "trad$i", 'example' => "A *word$i*.", 'example_es' => 'x']);
        }
    }

    private function user(array $attrs = []): User
    {
        $user = User::factory()->create($attrs + ['daily_new' => 5]);
        Sanctum::actingAs($user);

        return $user;
    }

    /** Responde bien las palabras de los niveles indicados y mal el resto. */
    private function answers(array $questions, array $correctLevels): array
    {
        return collect($questions)->map(function ($q) use ($correctLevels) {
            $word = Word::find($q['word_id']);
            $pos = $word->rank - 3;
            $level = $pos <= 10 ? 'A1' : ($pos <= 20 ? 'A2' : 'B1');

            return ['word_id' => $word->id, 'answer' => in_array($level, $correctLevels) ? $word->translation : 'mal'];
        })->all();
    }

    public function test_levels_overview_lists_every_level(): void
    {
        $this->user();

        $this->getJson('/api/levels')->assertOk()
            ->assertJsonPath('current', null)
            ->assertJsonCount(3, 'levels')
            ->assertJsonPath('levels.0.code', 'A1')
            ->assertJsonPath('levels.0.words', 10);
    }

    public function test_placement_has_questions_from_every_level_with_four_options(): void
    {
        $this->user();

        $qs = $this->getJson('/api/levels/placement')->assertOk()->json('questions');

        $this->assertCount(12, $qs);
        foreach ($qs as $q) {
            $this->assertCount(4, $q['options']);
            $this->assertContains(Word::find($q['word_id'])->translation, $q['options']);
            $this->assertNotSame('freelance', Word::find($q['word_id'])->source);
        }
    }

    public function test_placement_starts_at_the_first_level_not_mastered(): void
    {
        $user = $this->user();
        $qs = $this->getJson('/api/levels/placement')->json('questions');

        $this->postJson('/api/levels/placement', ['answers' => $this->answers($qs, ['A1', 'A2'])])
            ->assertOk()->assertJsonPath('level', 'B1');

        $this->assertSame('B1', $user->fresh()->cefr_level);
        $this->assertDatabaseHas('level_results', ['user_id' => $user->id, 'kind' => 'placement', 'level' => 'B1']);
    }

    public function test_placement_with_no_correct_answers_starts_at_a1(): void
    {
        $this->user();
        $qs = $this->getJson('/api/levels/placement')->json('questions');

        $this->postJson('/api/levels/placement', ['answers' => $this->answers($qs, [])])
            ->assertOk()->assertJsonPath('level', 'A1');
    }

    public function test_new_words_start_at_the_users_level_after_the_freelance_pack(): void
    {
        $this->user(['cefr_level' => 'A2', 'freelance_pack' => true]);

        $words = collect($this->getJson('/api/today')->json('cards'))->pluck('word')->all();

        // 3 de freelance y luego las primeras de A2 (posición 11 = word11).
        $this->assertSame(['scope', 'deadline', 'invoice', 'word11', 'word12'], $words);
    }

    public function test_freelance_pack_can_be_turned_off(): void
    {
        $this->user(['cefr_level' => 'A2']);
        $this->putJson('/api/settings', ['freelance_pack' => false])->assertOk()->assertJsonPath('freelance_pack', false);

        $words = collect($this->getJson('/api/today')->json('cards'))->pluck('word')->all();
        $this->assertSame(['word11', 'word12', 'word13', 'word14', 'word15'], $words);
    }

    public function test_exam_is_locked_until_most_words_of_the_level_are_learned(): void
    {
        $this->user(['cefr_level' => 'A1']);

        $this->getJson('/api/levels/exam')->assertUnprocessable();
        $this->getJson('/api/levels')->assertJsonPath('progress.exam_ready', false)
            ->assertJsonPath('progress.exam_needed', 8);
    }

    private function learnLevel(User $user, int $from, int $count): void
    {
        $ids = Word::where('source', 'ngsl')->orderBy('rank')->skip($from - 1)->limit($count)->pluck('id');
        foreach ($ids as $id) {
            UserWord::create(['user_id' => $user->id, 'word_id' => $id, 'level' => 1,
                'introduced_at' => now()->toDateString(), 'next_review' => now()->addDay()->toDateString()]);
        }
    }

    public function test_passing_the_exam_moves_up_a_level(): void
    {
        $user = $this->user(['cefr_level' => 'A1']);
        $this->learnLevel($user, 1, 8);

        $qs = $this->getJson('/api/levels/exam')->assertOk()->json('questions');
        $this->assertCount(10, $qs);

        $this->postJson('/api/levels/exam', ['answers' => $this->answers($qs, ['A1'])])
            ->assertOk()->assertJsonPath('passed', true)->assertJsonPath('level', 'A2');

        $this->assertSame('A2', $user->fresh()->cefr_level);
        $this->assertDatabaseHas('level_results', ['user_id' => $user->id, 'kind' => 'exam', 'passed' => true, 'new_level' => 'A2']);
    }

    public function test_failing_the_exam_keeps_the_level_and_lists_mistakes(): void
    {
        $user = $this->user(['cefr_level' => 'A1']);
        $this->learnLevel($user, 1, 8);
        $qs = $this->getJson('/api/levels/exam')->json('questions');

        $res = $this->postJson('/api/levels/exam', ['answers' => $this->answers($qs, [])])
            ->assertOk()->assertJsonPath('passed', false)->assertJsonPath('level', 'A1');

        $this->assertCount(10, $res->json('missed'));
        $this->assertSame('A1', $user->fresh()->cefr_level);
    }

    public function test_user_can_choose_a_level_manually(): void
    {
        $user = $this->user();

        $this->putJson('/api/levels/current', ['level' => 'B1'])->assertOk()->assertJsonPath('progress.level', 'B1');
        $this->putJson('/api/levels/current', ['level' => 'Z9'])->assertUnprocessable();
        $this->assertSame('B1', $user->fresh()->cefr_level);
    }

    public function test_reset_clears_level_and_history(): void
    {
        $user = $this->user(['cefr_level' => 'B1']);
        DB::table('level_results')->insert(['user_id' => $user->id, 'kind' => 'exam', 'level' => 'A2',
            'score' => 90, 'passed' => true, 'new_level' => 'B1', 'created_at' => now(), 'updated_at' => now()]);

        $this->postJson('/api/reset', ['password' => 'password'])->assertNoContent();

        $this->assertNull($user->fresh()->cefr_level);
        $this->assertDatabaseMissing('level_results', ['user_id' => $user->id]);
    }
}
