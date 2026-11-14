<?php

namespace Tests\Feature;

use App\Models\SpeakingMistake;
use App\Models\SpeakingSession;
use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\XpService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** "Hoy": sesión guiada y puntos (XP) que da siempre el servidor. */
class SessionTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create(['cefr_level' => 'B1', 'daily_new' => 10]);
        Sanctum::actingAs($this->user);
    }

    private function day(): string
    {
        return today(config('vocab.timezone'))->toDateString();
    }

    private function words(int $n, int $from = 1): array
    {
        return array_map(fn ($i) => Word::create(['word' => "word{$i}", 'rank' => $i, 'source' => 'ngsl', 'translation' => "palabra {$i}", 'example' => "A *word{$i}* here."]), range($from, $from + $n - 1));
    }

    public function test_the_plan_mixes_reviews_new_words_sounds_speaking_and_mistakes(): void
    {
        config(['services.unsplash.key' => null]);
        $this->user->forceFill(['cefr_level' => null])->save();   // sin nivel: las palabras nuevas salen de cualquier rango
        foreach ($this->words(7) as $w) {
            UserWord::create(['user_id' => $this->user->id, 'word_id' => $w->id, 'level' => 1, 'next_review' => $this->day(), 'introduced_at' => now()->subDays(3)]);
        }
        $this->words(5, 100);
        DB::table('phoneme_errors')->insert(['user_id' => $this->user->id, 'phoneme' => 'θ', 'count' => 5, 'created_at' => now(), 'updated_at' => now()]);
        foreach (range(1, 4) as $i) {
            SpeakingMistake::create(['user_id' => $this->user->id, 'said' => "a{$i}", 'correct' => "b{$i}", 'next_review' => $this->day()]);
        }

        $p = $this->getJson('/api/session/today')->assertOk();
        $this->assertCount(5, $p->json('plan.reviews'));
        $this->assertCount(3, $p->json('plan.new'));
        $this->assertSame('θ', $p->json('plan.sounds.0.phoneme'));
        $this->assertContains($p->json('plan.speak'), ['narrate', 'shadowing']);   // sin Unsplash no hay foto
        $this->assertCount(3, $p->json('plan.mistakes'));
        $p->assertJsonPath('xp.xp', 0)->assertJsonPath('xp.goal', 100);
    }

    public function test_points_come_from_real_actions_and_count_for_the_streak(): void
    {
        [$a, $b] = $this->words(2);
        $this->postJson("/api/words/{$a->id}/learn")->assertOk()->assertJsonPath('xp_gained', 5);
        $this->postJson("/api/words/{$a->id}/learn")->assertJsonPath('xp_gained', 0);           // aprender dos veces no suma
        $this->postJson("/api/words/{$a->id}/review", ['grade' => 'good'])->assertJsonPath('xp_gained', 3);
        $this->postJson("/api/words/{$a->id}/review", ['grade' => 'again'])->assertJsonPath('xp_gained', 1);

        $m = SpeakingMistake::create(['user_id' => $this->user->id, 'said' => 'he go', 'correct' => 'he goes', 'next_review' => $this->day()]);
        $this->postJson("/api/speaking/mistakes/{$m->id}/review", ['text' => 'he goes'])->assertJsonPath('xp_gained', 5);

        $s = SpeakingSession::create(['user_id' => $this->user->id, 'day' => $this->day(), 'words' => 300, 'speech_ms' => 120000]);
        $this->postJson("/api/speaking/sessions/{$s->id}/finish")->assertJsonPath('xp_gained', 20);
        $this->postJson("/api/speaking/sessions/{$s->id}/finish")->assertJsonPath('xp_gained', 0);  // terminar dos veces no suma

        $this->getJson('/api/session/today')->assertJsonPath('xp.xp', 34)->assertJsonPath('streak', 1);
        $this->assertSame(34, $this->user->fresh()->xp_total);
    }

    public function test_each_source_has_a_daily_cap(): void
    {
        $xp = app(XpService::class);
        $this->assertSame(60, array_sum(array_map(fn () => $xp->add($this->user, 'pronunciation'), range(1, 80))));
        $this->assertSame(0, $xp->add($this->user, 'nope'));
    }

    public function test_completing_the_session_gives_a_bonus_up_to_three_times_and_summarizes_the_day(): void
    {
        [$a] = $this->words(1);
        $this->postJson("/api/words/{$a->id}/learn");

        $r = $this->postJson('/api/session/complete')->assertOk();
        $r->assertJsonPath('xp_gained', 10)->assertJsonPath('today.learned', 1)->assertJsonPath('xp.sessions', 1)->assertJsonPath('streak', 1);
        $this->postJson('/api/session/complete');
        $this->postJson('/api/session/complete');
        $this->postJson('/api/session/complete')->assertJsonPath('xp_gained', 0);
    }

    public function test_the_daily_goal_can_be_changed_and_reset_clears_points(): void
    {
        $this->putJson('/api/settings', ['xp_goal' => 5])->assertUnprocessable();
        $this->putJson('/api/settings', ['xp_goal' => 150])->assertOk()->assertJsonPath('xp_goal', 150);
        app(XpService::class)->add($this->user, 'lab');
        $this->postJson('/api/reset', ['password' => 'password'])->assertNoContent();
        $this->assertSame(0, DB::table('xp_days')->where('user_id', $this->user->id)->count());
        $this->assertSame(0, $this->user->fresh()->xp_total);
    }
}
