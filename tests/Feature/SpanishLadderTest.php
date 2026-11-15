<?php

namespace Tests\Feature;

use App\Models\SpeakingSession;
use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Escalera de español: la app usa cada vez menos español según el nivel y lo que el alumno lo pide. */
class SpanishLadderTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create(['cefr_level' => 'B1', 'daily_new' => 10]);
        Sanctum::actingAs($this->user);
    }

    private function day(int $ago = 0): string
    {
        return today(config('vocab.timezone'))->subDays($ago)->toDateString();
    }

    private function studied(int $days): void
    {
        foreach (range(0, $days - 1) as $i) {
            DB::table('xp_days')->insert(['user_id' => $this->user->id, 'day' => $this->day($i), 'xp' => 20, 'created_at' => now(), 'updated_at' => now()]);
        }
    }

    /** Escucha de hoy: aciertos y fallos en Oído y "repeat"/"slower". */
    private function listened(int $ok, int $fail = 0, int $repeats = 0): void
    {
        DB::table('listening_days')->insert(['user_id' => $this->user->id, 'day' => $this->day(), 'ear_ok' => $ok, 'ear_fail' => $fail, 'repeats' => $repeats, 'created_at' => now(), 'updated_at' => now()]);
    }

    public function test_the_step_starts_from_the_level_but_at_most_simple_english(): void
    {
        // La prueba mide leer: hasta demostrar que entiende al oír, como mucho el escalón 2 (inglés sencillo).
        foreach (['A1' => 1, 'A2' => 1, 'B1' => 2, 'B2' => 2, 'C1' => 2] as $level => $step) {
            $this->user->forceFill(['cefr_level' => $level])->save();
            $this->getJson('/api/spanish')->assertOk()->assertJsonPath('step', $step)->assertJsonPath('auto', true)
                ->assertJsonPath('ui', $step >= 3 ? 'en' : 'es');
        }
        $this->getJson('/api/me')->assertOk()->assertJsonPath('spanish.step', 2)->assertJsonPath('spanish.level_step', 4);
    }

    public function test_understanding_by_ear_unlocks_the_step_of_the_level(): void
    {
        $this->user->forceFill(['cefr_level' => 'B2'])->save();
        $this->listened(18, 2);   // 90 % en 20 respuestas, sin pedir repetir
        $this->getJson('/api/spanish')->assertJsonPath('step', 3)->assertJsonPath('listening.verdict', 'good')
            ->assertJsonPath('listening.pct', 90);
        $this->studied(5);        // y casi sin español: uno más
        $this->getJson('/api/spanish')->assertJsonPath('step', 4);
    }

    public function test_struggling_by_ear_moves_down_a_step(): void
    {
        $this->user->forceFill(['cefr_level' => 'B2'])->save();
        $this->listened(4, 8);    // 33 % de aciertos
        $this->getJson('/api/spanish')->assertJsonPath('step', 1)->assertJsonPath('listening.verdict', 'struggling');
    }

    public function test_asking_to_repeat_a_lot_also_counts_as_struggling(): void
    {
        $this->user->forceFill(['cefr_level' => 'B1'])->save();
        foreach (range(1, 15) as $i) {
            $this->postJson('/api/listening/help', ['kind' => $i % 2 ? 'repeat' : 'slower'])->assertNoContent();
        }
        $this->getJson('/api/spanish')->assertJsonPath('listening.repeats', 15)->assertJsonPath('step', 1);
        $this->postJson('/api/listening/help', ['kind' => 'dance'])->assertUnprocessable();
    }

    public function test_ear_answers_are_recorded_for_the_ladder(): void
    {
        $word = \App\Models\Word::create(['word' => 'peach', 'rank' => 1, 'source' => 'ngsl', 'translation' => 'melocotón']);
        $uw = \App\Models\UserWord::create(['user_id' => $this->user->id, 'word_id' => $word->id, 'level' => 1, 'introduced_at' => $this->day(2), 'next_review' => $this->day(1)]);
        $ear = app(\App\Services\EarService::class);
        $ear->answer($this->user, $uw, true, 900);
        $ear->answer($this->user, $uw->fresh(), false, 3000);

        $this->assertSame(['answers' => 2, 'ok' => 1, 'pct' => 50, 'repeats' => 0], app(\App\Services\ListeningService::class)->week($this->user));
    }

    public function test_listening_data_is_only_your_own(): void
    {
        $other = User::factory()->create(['cefr_level' => 'B2']);
        DB::table('listening_days')->insert(['user_id' => $other->id, 'day' => $this->day(), 'ear_ok' => 30, 'ear_fail' => 0, 'repeats' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $this->user->forceFill(['cefr_level' => 'B2'])->save();
        $this->getJson('/api/spanish')->assertJsonPath('step', 2)->assertJsonPath('listening.answers', 0);
    }

    public function test_the_step_can_be_fixed_by_hand_and_back_to_auto(): void
    {
        $this->putJson('/api/spanish', ['step' => 4])->assertOk()->assertJsonPath('step', 4)->assertJsonPath('auto', false)->assertJsonPath('coach', 'en');
        $this->putJson('/api/spanish', ['step' => 9])->assertUnprocessable();
        $this->putJson('/api/spanish', ['step' => null])->assertOk()->assertJsonPath('step', 2)->assertJsonPath('auto', true)->assertJsonPath('coach', 'simple');
    }

    public function test_it_moves_up_a_step_after_a_week_almost_without_spanish(): void
    {
        $this->user->forceFill(['cefr_level' => 'A2'])->save();   // escalón 1 → 2 sin datos de escucha
        $this->studied(5);
        $this->getJson('/api/spanish')->assertJsonPath('step', 2);
        $this->user->forceFill(['cefr_level' => 'B1'])->save();   // del 2 al 3 hace falta demostrar que entiende al oír
        $this->getJson('/api/spanish')->assertJsonPath('step', 2);
        $this->listened(16, 2);
        $this->getJson('/api/spanish')->assertJsonPath('step', 3);
        DB::table('spanish_uses')->insert(['user_id' => $this->user->id, 'day' => $this->day(1), 'kind' => 'translation', 'count' => 4, 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/spanish')->assertJsonPath('step', 2)->assertJsonPath('week', 4);
    }

    public function test_asking_for_spanish_counts_and_has_a_daily_limit_from_step_three(): void
    {
        $this->postJson('/api/spanish/use', ['kind' => 'translation'])->assertOk()->assertJsonPath('left', null);
        $this->postJson('/api/spanish/use', ['kind' => 'nope'])->assertUnprocessable();

        $this->user->forceFill(['spanish_step' => 3])->save();
        foreach (range(1, 4) as $i) {
            $this->postJson('/api/spanish/use', ['kind' => 'hint'])->assertOk();
        }
        $this->postJson('/api/spanish/use', ['kind' => 'hint'])->assertStatus(429);
        $this->getJson('/api/spanish')->assertJsonPath('today', 5)->assertJsonPath('left', 0);

        $this->user->forceFill(['spanish_step' => 4])->save();
        $this->postJson('/api/spanish/use', ['kind' => 'translation'])->assertStatus(429);
    }

    public function test_the_streak_counts_study_days_without_spanish(): void
    {
        $this->studied(4);
        $this->getJson('/api/spanish')->assertJsonPath('streak', 4);
        DB::table('spanish_uses')->insert(['user_id' => $this->user->id, 'day' => $this->day(2), 'kind' => 'translation', 'count' => 1, 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/spanish')->assertJsonPath('streak', 2);
    }

    public function test_slow_starts_flag_that_you_are_translating(): void
    {
        SpeakingSession::create(['user_id' => $this->user->id, 'scenario' => 'free', 'day' => $this->day(), 'reaction_ms' => 8000, 'reaction_turns' => 2]);
        $this->getJson('/api/spanish')->assertJsonPath('reaction', 4)->assertJsonPath('translating', true);
    }

    public function test_cards_bring_less_spanish_on_higher_steps(): void
    {
        $w = Word::create(['word' => 'deadline', 'rank' => 1, 'source' => 'ngsl', 'translation' => 'plazo', 'example' => 'We missed the *deadline*.', 'definition' => 'the last day to finish something']);
        UserWord::create(['user_id' => $this->user->id, 'word_id' => $w->id, 'level' => 1, 'next_review' => $this->day(), 'introduced_at' => now()->subDays(3)]);

        $this->user->forceFill(['spanish_step' => 1])->save();
        $this->getJson('/api/session/today')->assertJsonPath('plan.reviews.0.english_only', false)->assertJsonPath('plan.reviews.0.hide_translation', false);

        $this->user->forceFill(['spanish_step' => 3])->save();
        $this->getJson('/api/session/today')->assertJsonPath('plan.reviews.0.english_only', true)
            ->assertJsonPath('plan.reviews.0.hide_translation', true)->assertJsonPath('plan.reviews.0.no_spanish', false);

        $this->user->forceFill(['spanish_step' => 4])->save();
        $this->getJson('/api/session/today')->assertJsonPath('plan.reviews.0.no_spanish', true);
    }

    public function test_the_coach_explains_in_the_language_of_the_step(): void
    {
        config(['vocab.anthropic.key' => 'test-key']);
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => "COMMENT: Nice.\nBETTER: I like it.\nFEEDBACK: Good job.\nFIX: he go => he goes | third person adds -s | verb"]]])]);
        $s = SpeakingSession::create(['user_id' => $this->user->id, 'scenario' => 'narrate', 'day' => $this->day(), 'topic' => 'your day']);

        $this->user->forceFill(['spanish_step' => 4])->save();
        $this->postJson("/api/speaking/sessions/{$s->id}/narration", ['text' => 'he go to work'])->assertOk();
        Http::assertSent(fn (HttpRequest $r) => str_contains($r['system'], '"FEEDBACK:" in English') && ! str_contains($r['system'], 'in Spanish'));

        $this->user->forceFill(['spanish_step' => 1])->save();
        $this->postJson("/api/speaking/sessions/{$s->id}/narration", ['text' => 'he go to work'])->assertOk();
        Http::assertSent(fn (HttpRequest $r) => str_contains($r['system'], '"FEEDBACK:" in Spanish'));
    }

    public function test_translate_a_short_text_counts_as_spanish(): void
    {
        config(['vocab.anthropic.key' => 'test-key']);
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => 'Buen trabajo.']]])]);
        $this->postJson('/api/spanish/translate', ['text' => 'Good job.'])->assertOk()->assertJsonPath('text', 'Buen trabajo.');
        $this->getJson('/api/spanish')->assertJsonPath('today', 1);
    }
}
