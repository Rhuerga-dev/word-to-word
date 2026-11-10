<?php

namespace Tests\Feature;

use App\Models\SpeakingMistake;
use App\Models\SpeakingSession;
use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\ClaudeService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Panel de progreso: datos de cada área y lo que conviene hacer hoy. */
class ProgressTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create(['cefr_level' => 'B1']);
        Sanctum::actingAs($this->user);
    }

    private function day(): string
    {
        return today(config('vocab.timezone'))->toDateString();
    }

    public function test_the_ai_marks_the_type_of_each_mistake(): void
    {
        $out = ClaudeService::parseTurn("Ok!\nFIX: he go => he goes | tercera persona | agreement\nFIX: in Monday => on Monday | con días se usa on\nUSED: none");
        $this->assertSame('agreement', $out['mistakes'][0]['category']);
        $this->assertSame('tercera persona', $out['mistakes'][0]['why']);
        $this->assertNull($out['mistakes'][1]['category']);
        $this->assertSame('con días se usa on', $out['mistakes'][1]['why']);
    }

    public function test_progress_has_every_area_and_counts_mistakes_by_type(): void
    {
        $w = Word::create(['word' => 'borrow', 'rank' => 1, 'source' => 'ngsl', 'translation' => 'pedir prestado', 'example' => 'Can I *borrow* it?']);
        UserWord::create(['user_id' => $this->user->id, 'word_id' => $w->id, 'level' => 5, 'next_review' => $this->day(), 'introduced_at' => now()]);
        SpeakingSession::create(['user_id' => $this->user->id, 'day' => $this->day(), 'words' => 200, 'speech_ms' => 120000]);
        foreach (['tense', 'tense', 'preposition', null] as $cat) {
            SpeakingMistake::create(['user_id' => $this->user->id, 'said' => 'a', 'correct' => 'b'.uniqid(), 'category' => $cat, 'next_review' => $this->day()]);
        }
        DB::table('phoneme_errors')->insert(['user_id' => $this->user->id, 'phoneme' => 'θ', 'count' => 4, 'tier' => 'g', 'created_at' => now(), 'updated_at' => now()]);

        $p = $this->getJson('/api/progress')->assertOk();
        $p->assertJsonPath('vocab.learned', 1)->assertJsonPath('vocab.due', 1)->assertJsonPath('vocab.by_level.5', 1)
            ->assertJsonPath('speaking.today', 2)->assertJsonPath('mistakes.pending', 4)
            ->assertJsonPath('mistakes.by_category.0.category', 'tense')->assertJsonPath('mistakes.by_category.0.count', 2)
            ->assertJsonPath('pronunciation.sounds.0.tier', 'g');
        $this->assertCount(8, $p->json('speaking.weeks'));

        // Lo de hoy: fichas, minutos que faltan, errores... (máx. 4)
        $actions = array_column($p->json('todo'), 'action');
        $this->assertSame(['cards', 'speak', 'review', 'narrate'], $actions);
    }

    public function test_when_everything_is_done_there_is_nothing_left_for_today(): void
    {
        SpeakingSession::create(['user_id' => $this->user->id, 'scenario' => 'narrate', 'day' => $this->day(), 'words' => 600, 'speech_ms' => 6 * 60000]);
        $this->getJson('/api/progress')->assertOk()->assertJsonPath('todo', []);
    }

    public function test_progress_only_shows_your_own_data(): void
    {
        $other = User::factory()->create();
        SpeakingMistake::create(['user_id' => $other->id, 'said' => 'a', 'correct' => 'b', 'next_review' => $this->day()]);
        $this->getJson('/api/progress')->assertJsonPath('mistakes.pending', 0);
    }
}
