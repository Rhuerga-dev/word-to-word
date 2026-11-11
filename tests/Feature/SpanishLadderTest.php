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

    public function test_the_step_starts_from_the_level(): void
    {
        foreach (['A1' => 1, 'A2' => 1, 'B1' => 2, 'B2' => 3, 'C1' => 4] as $level => $step) {
            $this->user->forceFill(['cefr_level' => $level])->save();
            $this->getJson('/api/spanish')->assertOk()->assertJsonPath('step', $step)->assertJsonPath('auto', true)
                ->assertJsonPath('ui', $step >= 3 ? 'en' : 'es');
        }
        $this->getJson('/api/me')->assertOk()->assertJsonPath('spanish.step', 4);
    }

    public function test_the_step_can_be_fixed_by_hand_and_back_to_auto(): void
    {
        $this->putJson('/api/spanish', ['step' => 4])->assertOk()->assertJsonPath('step', 4)->assertJsonPath('auto', false)->assertJsonPath('coach', 'en');
        $this->putJson('/api/spanish', ['step' => 9])->assertUnprocessable();
        $this->putJson('/api/spanish', ['step' => null])->assertOk()->assertJsonPath('step', 2)->assertJsonPath('auto', true)->assertJsonPath('coach', 'simple');
    }

    public function test_it_moves_up_a_step_after_a_week_almost_without_spanish(): void
    {
        $this->studied(5);
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
