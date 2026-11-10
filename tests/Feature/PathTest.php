<?php

namespace Tests\Feature;

use App\Models\SpeakingSession;
use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\LevelService;
use App\Services\UnitService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Camino: unidades en orden, pasos de cada una y la prueba de conversación que desbloquea la siguiente. */
class PathTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        config(['vocab.anthropic.key' => 'test-key', 'units.words_target' => 2, 'units.levels' => ['B1' => [
            ['id' => 'b1-one', 'title' => 'Uno', 'words' => ['client', 'budget', 'invoice'], 'sound' => 'θ', 'scenario' => 'upwork_call', 'shadow' => 'a phone call with a client'],
            ['id' => 'b1-two', 'title' => 'Dos', 'words' => ['doctor'], 'sound' => 'v', 'scenario' => 'doctor', 'shadow' => 'at the doctor'],
        ]]]);
        foreach (['client', 'budget', 'invoice', 'doctor'] as $i => $w) {
            Word::create(['word' => $w, 'rank' => 10 + $i, 'source' => 'ngsl', 'translation' => 'x', 'example' => "A *{$w}*."]);
        }
        $this->user = User::factory()->create(['cefr_level' => 'B1', 'daily_new' => 10]);
        Sanctum::actingAs($this->user);
    }

    private function day(): string
    {
        return today(config('vocab.timezone'))->toDateString();
    }

    /** Completa palabras, sonido y shadowing de la primera unidad. */
    private function prepareFirstUnit(): void
    {
        foreach ($this->getJson('/api/path/units/b1-one/words')->json('cards') as $c) {
            $this->postJson("/api/words/{$c['id']}/learn")->assertOk();
        }
        $this->postJson('/api/pronunciation/sounds/result', ['phoneme' => 'θ', 'passed' => true, 'tier' => 'g', 'helps' => 1])->assertOk();
        $this->postJson('/api/path/units/b1-one/shadow', ['score' => 82])->assertOk();
    }

    private function messages(int $turns): array
    {
        $m = [];
        foreach (range(1, $turns) as $i) {
            $m[] = ['role' => 'assistant', 'content' => "Question {$i}?"];
            $m[] = ['role' => 'user', 'content' => "My answer number {$i} about the project"];
        }

        return $m;
    }

    public function test_the_first_unit_is_open_and_the_next_ones_locked(): void
    {
        $p = $this->getJson('/api/path')->assertOk();
        $p->assertJsonPath('level', 'B1')->assertJsonPath('current', 'b1-one')
            ->assertJsonPath('units.0.state', 'open')->assertJsonPath('units.1.state', 'locked')
            ->assertJsonPath('units.0.words.need', 2)->assertJsonPath('units.0.test_ready', false);

        $this->getJson('/api/path/units/b1-two/words')->assertNotFound();      // bloqueada
        $this->getJson('/api/path/units/nope/words')->assertNotFound();
    }

    public function test_the_steps_are_marked_as_you_do_them(): void
    {
        $this->assertCount(3, $this->getJson('/api/path/units/b1-one/words')->json('cards'));
        $this->postJson('/api/path/units/b1-one/shadow', ['score' => 40])->assertStatus(422);
        $this->prepareFirstUnit();

        $u = $this->getJson('/api/path')->json('units.0');
        $this->assertSame(['words' => true, 'sound' => true, 'shadow' => true, 'test' => false], $u['steps']);
        $this->assertTrue($u['test_ready']);
    }

    public function test_the_test_needs_the_other_steps_enough_turns_and_the_right_situation(): void
    {
        $s = SpeakingSession::create(['user_id' => $this->user->id, 'scenario' => 'upwork_call', 'day' => $this->day()]);
        $this->postJson('/api/path/units/b1-one/test', ['session_id' => $s->id, 'messages' => $this->messages(6)])->assertStatus(422);

        $this->prepareFirstUnit();
        Http::fake();
        $this->postJson('/api/path/units/b1-one/test', ['session_id' => $s->id, 'messages' => $this->messages(2)])
            ->assertOk()->assertJsonPath('passed', false)->assertJsonPath('score', null);

        $other = SpeakingSession::create(['user_id' => $this->user->id, 'scenario' => 'doctor', 'day' => $this->day()]);
        $this->postJson('/api/path/units/b1-one/test', ['session_id' => $other->id, 'messages' => $this->messages(6)])->assertStatus(422);
        Http::assertNothingSent();
    }

    public function test_passing_the_test_completes_the_unit_unlocks_the_next_and_gives_points(): void
    {
        $this->prepareFirstUnit();
        $s = SpeakingSession::create(['user_id' => $this->user->id, 'scenario' => 'upwork_call', 'day' => $this->day()]);

        Http::fake(['*' => Http::sequence()
            ->push(['content' => [['type' => 'text', 'text' => "SCORE: 4\nFEEDBACK: Respondiste poco."]]])
            ->push(['content' => [['type' => 'text', 'text' => "SCORE: 8\nFEEDBACK: ¡Muy bien! Explicaste tu experiencia con claridad."]]])]);

        $this->postJson('/api/path/units/b1-one/test', ['session_id' => $s->id, 'messages' => $this->messages(6)])
            ->assertJsonPath('passed', false)->assertJsonPath('score', 4)->assertJsonPath('path.units.1.state', 'locked');
        $r = $this->postJson('/api/path/units/b1-one/test', ['session_id' => $s->id, 'messages' => $this->messages(6)])->assertOk();
        $r->assertJsonPath('passed', true)->assertJsonPath('score', 8)->assertJsonPath('xp_gained', 50)
            ->assertJsonPath('path.units.0.state', 'done')->assertJsonPath('path.units.1.state', 'open')->assertJsonPath('path.current', 'b1-two');
        $this->assertSame(2, DB::table('unit_progress')->where('unit', 'b1-one')->value('test_tries'));
    }

    public function test_unit_words_never_appear_as_new_words_elsewhere(): void
    {
        $w = Word::create(['word' => 'scope', 'rank' => 1, 'source' => UnitService::SOURCE, 'translation' => 'alcance', 'example' => 'The *scope*.']);
        $this->assertFalse(app(LevelService::class)->general()->where('id', $w->id)->exists());
    }

    public function test_units_sync_creates_the_missing_words(): void
    {
        config(['units.levels' => ['B1' => [['id' => 'x', 'title' => 'X', 'words' => ['client', 'luggage'], 'sound' => 'θ', 'scenario' => 'free', 'shadow' => 'x']]]]);
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => '{"luggage": {"translation": "equipaje", "example": "My *luggage* is heavy.", "example_es": "Mi equipaje pesa."}}']]])]);
        $this->artisan('units:sync')->assertSuccessful();
        $this->assertSame(UnitService::SOURCE, Word::firstWhere('word', 'luggage')->source);
        $this->assertSame(1, Word::where('word', 'client')->count());
    }
}
