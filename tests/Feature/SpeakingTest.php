<?php

namespace Tests\Feature;

use App\Models\SpeakingMistake;
use App\Models\SpeakingSession;
use App\Models\User;
use App\Services\PronunciationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Hablar: conversación por voz, situaciones, métricas de fluidez y errores para repasar. */
class SpeakingTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        config(['vocab.anthropic.key' => 'test-key', 'vocab.azure_speech.key' => 'test-key']);
        $this->user = User::factory()->create();
        Sanctum::actingAs($this->user);
    }

    /** El "hoy" de la app (zona horaria de config/vocab.php). */
    private function day(): string
    {
        return today(config('vocab.timezone'))->toDateString();
    }

    private function talk(array $extra = []): SpeakingSession
    {
        return SpeakingSession::create(['user_id' => $this->user->id, 'scenario' => 'free', 'day' => $this->day()] + $extra);
    }

    /** Azure: palabras con inicio y duración en unidades de 100 ns. */
    private function azureWords(array $words): array
    {
        return ['RecognitionStatus' => 'Success', 'NBest' => [[
            'Display' => implode(' ', array_column($words, 0)).'.',
            'Words' => array_map(fn ($w) => ['Word' => $w[0], 'Offset' => $w[1] * 10000, 'Duration' => $w[2] * 10000], $words),
        ]]];
    }

    private function wav(): UploadedFile
    {
        return UploadedFile::fake()->createWithContent('voz.wav', str_repeat("\0", 2000));
    }

    public function test_lists_the_situations_and_starts_a_session(): void
    {
        $ids = array_column($this->getJson('/api/speaking/scenarios')->assertOk()->json('scenarios'), 'id');
        $this->assertContains('upwork_call', $ids);
        $this->assertContains('present_project', $ids);

        $this->postJson('/api/speaking/sessions', ['scenario' => 'nope'])->assertUnprocessable();
        $id = $this->postJson('/api/speaking/sessions', ['scenario' => 'upwork_call'])->assertCreated()->json('id');
        $this->assertSame($this->user->id, SpeakingSession::find($id)->user_id);
    }

    public function test_a_voice_turn_is_transcribed_and_measures_rhythm_and_long_pauses(): void
    {
        // 6 palabras en 3 s, con una pausa de 1 s en medio.
        Http::fake(['*' => Http::response($this->azureWords([
            ['I', 0, 200], ['have', 250, 250], ['three', 550, 300], ['years', 1850, 300], ['of', 2200, 150], ['experience', 2400, 600],
        ]))]);
        $s = $this->talk();

        $r = $this->post("/api/speaking/sessions/{$s->id}/turns", ['audio' => $this->wav()], ['Accept' => 'application/json'])->assertOk();
        $r->assertJsonPath('text', 'I have three years of experience.')->assertJsonPath('words', 6)
            ->assertJsonPath('speech_ms', 3000)->assertJsonPath('long_pauses', 1)->assertJsonPath('wpm', 120);

        $s->refresh();
        $this->assertSame([1, 6, 3000, 1], [$s->turns, $s->words, $s->speech_ms, $s->long_pauses]);
        Http::assertSent(fn (HttpRequest $req) => str_contains($req->url(), 'wordLevelTimestamps=true') && ! $req->hasHeader('Pronunciation-Assessment'));
    }

    public function test_without_azure_the_browser_text_and_duration_are_used(): void
    {
        $s = $this->talk();
        $this->postJson("/api/speaking/sessions/{$s->id}/turns", ['text' => 'I work as a web developer', 'ms' => 3000])
            ->assertOk()->assertJsonPath('words', 6)->assertJsonPath('wpm', 120);
        $this->assertSame(3000, $s->refresh()->speech_ms);
    }

    public function test_sessions_of_other_users_and_finished_ones_are_refused(): void
    {
        $other = SpeakingSession::create(['user_id' => User::factory()->create()->id, 'scenario' => 'free', 'day' => $this->day()]);
        $this->postJson("/api/speaking/sessions/{$other->id}/turns", ['text' => 'hello there friend', 'ms' => 1000])->assertNotFound();
        $this->postJson("/api/speaking/sessions/{$other->id}/finish")->assertNotFound();

        $mine = $this->talk(['ended_at' => now()]);
        $this->postJson("/api/speaking/sessions/{$mine->id}/turns", ['text' => 'hello there friend', 'ms' => 1000])->assertStatus(409);
    }

    public function test_the_conversation_plays_the_situation_and_saves_mistakes_once(): void
    {
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => "Nice! When can you start?\nFEEDBACK: Bien, solo un detalle.\nFIX: I have 3 years working => I've been working for 3 years | Para duración usa present perfect\nUSED: none"]]])]);
        $s = $this->talk(['scenario' => 'upwork_call']);
        $msgs = [['role' => 'assistant', 'content' => 'Hi, tell me about you.'], ['role' => 'user', 'content' => 'i have 3 years working']];

        $r = $this->postJson('/api/conversation', ['messages' => $msgs, 'scenario' => 'upwork_call', 'voice' => true, 'session_id' => $s->id])->assertOk();
        $r->assertJsonPath('reply', 'Nice! When can you start?')->assertJsonPath('mistakes.0.correct', "I've been working for 3 years");

        Http::assertSent(function (HttpRequest $req) {
            $body = $req->data();

            // El papel de la situación va en las instrucciones; la API recibe primero un mensaje del alumno.
            return str_contains($body['system'], 'Upwork') && str_contains($body['system'], 'speech-to-text') && $body['messages'][0]['role'] === 'user';
        });

        $m = SpeakingMistake::sole();
        $this->assertSame($s->id, $m->speaking_session_id);
        $this->assertSame($this->day(), $m->next_review->toDateString()); // se repasa hoy mismo

        // El mismo error otra vez no se duplica.
        $this->postJson('/api/conversation', ['messages' => $msgs, 'scenario' => 'upwork_call', 'session_id' => $s->id])->assertOk();
        $this->assertSame(1, SpeakingMistake::count());
    }

    public function test_a_session_id_of_another_user_is_ignored(): void
    {
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => "Hi!\nFIX: he go => he goes\nUSED: none"]]])]);
        $other = SpeakingSession::create(['user_id' => User::factory()->create()->id, 'scenario' => 'free', 'day' => $this->day()]);
        $this->postJson('/api/conversation', ['messages' => [['role' => 'user', 'content' => 'he go']], 'session_id' => $other->id])->assertOk();
        $this->assertNull(SpeakingMistake::sole()->speaking_session_id);
        $this->assertSame($this->user->id, SpeakingMistake::sole()->user_id);
    }

    public function test_finishing_returns_the_summary_and_today_against_the_goal(): void
    {
        $s = $this->talk(['turns' => 4, 'words' => 240, 'speech_ms' => 120000, 'long_pauses' => 6]);
        SpeakingMistake::create(['user_id' => $this->user->id, 'speaking_session_id' => $s->id, 'said' => 'he go', 'correct' => 'he goes', 'next_review' => $this->day()]);

        $r = $this->postJson("/api/speaking/sessions/{$s->id}/finish")->assertOk();
        $r->assertJsonPath('minutes', 2.0)->assertJsonPath('wpm', 120)->assertJsonPath('pauses_per_min', 3.0)
            ->assertJsonPath('mistakes.0.correct', 'he goes')->assertJsonPath('stats.today', 2.0)->assertJsonPath('stats.goal', 5);
        $this->assertNotNull($s->refresh()->ended_at);
    }

    public function test_reviewing_a_mistake_by_saying_it_right_spaces_it_and_wrong_brings_it_back(): void
    {
        $m = SpeakingMistake::create(['user_id' => $this->user->id, 'said' => 'he go to work', 'correct' => 'He goes to work.', 'next_review' => $this->day()]);

        $this->postJson("/api/speaking/mistakes/{$m->id}/review", ['text' => 'he go to work'])
            ->assertOk()->assertJsonPath('passed', false)->assertJsonPath('days', 1)->assertJsonPath('tokens.1.ok', false);

        $this->user->increment('day_offset');
        $this->postJson("/api/speaking/mistakes/{$m->id}/review", ['text' => 'He goes to work'])
            ->assertOk()->assertJsonPath('passed', true)->assertJsonPath('stage', 1)->assertJsonPath('days', 1);

        // Sin voz no cuenta como fallo.
        $this->postJson("/api/speaking/mistakes/{$m->id}/review", ['text' => 'mmm'])->assertJsonPath('silent', true);
        $this->assertSame(1, $m->refresh()->stage);

        $this->assertSame([], $this->getJson('/api/speaking/mistakes')->json('mistakes')); // vuelve mañana
    }

    public function test_five_spaced_passes_master_a_mistake(): void
    {
        $m = SpeakingMistake::create(['user_id' => $this->user->id, 'said' => 'he go', 'correct' => 'he goes', 'next_review' => $this->day()]);
        foreach ([1, 3, 7, 14, 30] as $i => $days) {
            $r = $this->postJson("/api/speaking/mistakes/{$m->id}/review", ['text' => 'he goes'])->assertJsonPath('days', $days);
            $this->user->increment('day_offset', $days);
        }
        $r->assertJsonPath('mastered', true);
        $this->getJson('/api/speaking/stats')->assertJsonPath('mistakes_mastered', 1)->assertJsonPath('mistakes_due', 0);
    }

    public function test_review_with_audio_uses_azure_and_others_mistakes_are_hidden(): void
    {
        Http::fake(['*' => Http::response($this->azureWords([['he', 0, 200], ['goes', 300, 300]]))]);
        $m = SpeakingMistake::create(['user_id' => $this->user->id, 'said' => 'he go', 'correct' => 'he goes', 'next_review' => $this->day()]);
        $this->post("/api/speaking/mistakes/{$m->id}/review", ['audio' => $this->wav()], ['Accept' => 'application/json'])->assertJsonPath('passed', true);

        $other = SpeakingMistake::create(['user_id' => User::factory()->create()->id, 'said' => 'a', 'correct' => 'b', 'next_review' => $this->day()]);
        $this->postJson("/api/speaking/mistakes/{$other->id}/review", ['text' => 'b'])->assertNotFound();
        // El mío ya se aprobó (vuelve mañana) y el del otro alumno nunca aparece.
        $this->assertSame([], $this->getJson('/api/speaking/mistakes')->json('mistakes'));
    }

    public function test_stats_count_minutes_per_day_and_the_goal_streak(): void
    {
        $today = today(config('vocab.timezone'));
        $this->putJson('/api/speaking/goal', ['speaking_goal' => 0])->assertUnprocessable();
        $this->putJson('/api/speaking/goal', ['speaking_goal' => 3])->assertOk();
        foreach ([[0, 4], [1, 3], [2, 1], [3, 5]] as [$ago, $min]) {
            SpeakingSession::create(['user_id' => $this->user->id, 'day' => $today->copy()->subDays($ago), 'words' => $min * 100, 'speech_ms' => $min * 60000, 'long_pauses' => $min]);
        }

        $st = $this->getJson('/api/speaking/stats')->assertOk();
        $st->assertJsonPath('today', 4.0)->assertJsonPath('goal', 3)->assertJsonPath('streak', 2)->assertJsonPath('total_minutes', 13.0);
        $this->assertSame([0, 0, 0, 5, 1, 3, 4], array_map('intval', array_column($st->json('week'), 'minutes')));
        $this->assertSame(100, $st->json('wpm.3.wpm'));
        $this->getJson('/api/me')->assertJsonPath('speaking_goal', 3);
    }

    public function test_fluency_counts_pauses_and_needs_three_words_for_a_rhythm(): void
    {
        $this->assertSame(['words' => 0, 'speech_ms' => 0, 'long_pauses' => 0, 'wpm' => null], PronunciationService::fluency([]));
        $this->assertNull(PronunciationService::fluency([['start' => 0, 'end' => 300], ['start' => 400, 'end' => 600]])['wpm']);
        $f = PronunciationService::fluency([['start' => 0, 'end' => 300], ['start' => 1000, 'end' => 1300], ['start' => 1350, 'end' => 2000]]);
        $this->assertSame(1, $f['long_pauses']);
        $this->assertSame(90, $f['wpm']);
    }

    public function test_reset_also_deletes_the_speaking_practice(): void
    {
        $s = $this->talk(['speech_ms' => 1000]);
        SpeakingMistake::create(['user_id' => $this->user->id, 'speaking_session_id' => $s->id, 'said' => 'a', 'correct' => 'b', 'next_review' => $this->day()]);
        $this->postJson('/api/reset')->assertNoContent();
        $this->assertSame(0, SpeakingSession::count() + SpeakingMistake::count());
    }
}
