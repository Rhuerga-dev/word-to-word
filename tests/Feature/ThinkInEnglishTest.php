<?php

namespace Tests\Feature;

use App\Models\SpeakingMistake;
use App\Models\SpeakingSession;
use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Pensar en inglés: fichas sin español, tiempo para arrancar a hablar y narración diaria. */
class ThinkInEnglishTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        config(['vocab.anthropic.key' => 'test-key']);
        $this->user = User::factory()->create(['cefr_level' => 'B1']);
        Sanctum::actingAs($this->user);
    }

    private function day(): string
    {
        return today(config('vocab.timezone'))->toDateString();
    }

    public function test_advanced_reviews_come_without_spanish_and_new_ones_with_it(): void
    {
        $borrow = Word::create(['word' => 'borrow', 'rank' => 1, 'source' => 'ngsl', 'translation' => 'pedir prestado', 'example' => 'Can I *borrow* your pen?', 'definition' => 'to take something and give it back later']);
        $hand = Word::create(['word' => 'hand', 'rank' => 2, 'source' => 'ngsl', 'translation' => 'mano', 'example' => 'My *hand*.']);
        $base = ['user_id' => $this->user->id, 'next_review' => $this->day(), 'introduced_at' => now()->subDays(20)];
        UserWord::create($base + ['word_id' => $borrow->id, 'level' => 3]);
        UserWord::create($base + ['word_id' => $hand->id, 'level' => 1]);

        $cards = collect($this->getJson('/api/today')->assertOk()->json('cards'))->keyBy('word');
        $this->assertTrue($cards['borrow']['english_only']);
        $this->assertSame('to take something and give it back later', $cards['borrow']['definition']);
        $this->assertFalse($cards['hand']['english_only']);
    }

    public function test_definitions_are_written_for_studied_words_and_never_give_the_answer_away(): void
    {
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => '{"borrow": "to take something and give it back later", "hand": "the hand at the end of your arm"}']]])]);
        $borrow = Word::create(['word' => 'borrow', 'rank' => 1, 'source' => 'ngsl', 'translation' => 'pedir prestado', 'example' => 'Can I *borrow* it?']);
        $hand = Word::create(['word' => 'hand', 'rank' => 2, 'source' => 'ngsl', 'translation' => 'mano', 'example' => 'My *hand*.']);
        $unseen = Word::create(['word' => 'cloud', 'rank' => 3, 'source' => 'ngsl', 'translation' => 'nube', 'example' => 'A *cloud*.']);
        foreach ([$borrow, $hand] as $w) {
            UserWord::create(['user_id' => $this->user->id, 'word_id' => $w->id, 'level' => 1, 'next_review' => $this->day(), 'introduced_at' => now()]);
        }

        $this->artisan('words:define')->assertSuccessful();

        $this->assertSame('to take something and give it back later', $borrow->refresh()->definition);
        $this->assertNull($hand->refresh()->definition);   // usaba la propia palabra
        $this->assertNull($unseen->refresh()->definition); // nadie la estudia todavía
        Http::assertSent(fn (HttpRequest $r) => ! str_contains($r->data()['messages'][0]['content'], 'cloud'));
    }

    public function test_the_time_to_start_speaking_is_averaged_per_session_and_week(): void
    {
        $s = SpeakingSession::create(['user_id' => $this->user->id, 'scenario' => 'free', 'day' => $this->day()]);
        $this->postJson("/api/speaking/sessions/{$s->id}/turns", ['text' => 'I think that is a great idea', 'ms' => 2000, 'reaction_ms' => 1000])->assertOk();
        $this->postJson("/api/speaking/sessions/{$s->id}/turns", ['text' => 'We can start on Monday then', 'ms' => 2000, 'reaction_ms' => 2000])->assertOk();
        $this->postJson("/api/speaking/sessions/{$s->id}/turns", ['text' => 'Sure', 'ms' => 500])->assertOk(); // sin medir

        $this->postJson("/api/speaking/sessions/{$s->id}/finish")->assertJsonPath('reaction', 1.5)->assertJsonPath('stats.reaction', 1.5);
        $this->postJson("/api/speaking/sessions/{$s->id}/turns", ['text' => 'x', 'ms' => 1, 'reaction_ms' => 999999])->assertStatus(409);
    }

    public function test_daily_narration_has_a_topic_and_returns_a_natural_version_and_up_to_five_fixes(): void
    {
        $st = $this->getJson('/api/speaking/stats')->assertOk();
        $this->assertNotEmpty($st->json('topic.en'));
        $this->assertFalse($st->json('narrated_today'));

        $r = $this->postJson('/api/speaking/sessions', ['scenario' => 'narrate'])->assertCreated();
        $id = $r->json('id');
        $this->assertSame($r->json('topic.en'), SpeakingSession::find($id)->topic);
        $this->assertNotSame($r->json('topic.en'), $this->postJson('/api/speaking/sessions', ['scenario' => 'narrate', 'skip' => 1])->json('topic.en'));

        $fixes = implode("\n", array_map(fn ($i) => "FIX: I go{$i} => I went{$i} | pasado", range(1, 7)));
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => "COMMENT: Sounds like a busy morning!\nBETTER: This morning I woke up early and went to the gym.\nFEEDBACK: ¡Muy bien!\n{$fixes}"]]])]);
        $this->postJson("/api/speaking/sessions/{$id}/turns", ['text' => 'this morning I wake up early and I go to the gym', 'ms' => 5000])->assertOk();

        $fb = $this->postJson("/api/speaking/sessions/{$id}/narration", ['text' => 'this morning I wake up early and I go to the gym'])->assertOk();
        $fb->assertJsonPath('comment', 'Sounds like a busy morning!')->assertJsonPath('better', 'This morning I woke up early and went to the gym.');
        $this->assertCount(5, $fb->json('mistakes'));
        $this->assertSame(5, SpeakingMistake::where('speaking_session_id', $id)->count());
        Http::assertSent(fn (HttpRequest $req) => str_contains($req->data()['system'], SpeakingSession::find($id)->topic));

        $this->getJson('/api/speaking/stats')->assertJsonPath('narrated_today', true);
    }

    public function test_narration_feedback_only_for_your_own_narration_sessions(): void
    {
        $free = SpeakingSession::create(['user_id' => $this->user->id, 'scenario' => 'free', 'day' => $this->day()]);
        $this->postJson("/api/speaking/sessions/{$free->id}/narration", ['text' => 'hello there'])->assertStatus(422);
        $other = SpeakingSession::create(['user_id' => User::factory()->create()->id, 'scenario' => 'narrate', 'day' => $this->day()]);
        $this->postJson("/api/speaking/sessions/{$other->id}/narration", ['text' => 'hello there'])->assertNotFound();
    }
}
