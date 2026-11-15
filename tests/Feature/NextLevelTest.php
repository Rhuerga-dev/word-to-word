<?php

namespace Tests\Feature;

use App\Models\SpeakingMistake;
use App\Models\SpeakingSession;
use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use App\Notifications\StudyReminder;
use App\Services\ClaudeService;
use App\Services\Fsrs;
use App\Services\ReminderService;
use App\Services\SrsService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Mejoras del 15-nov: protector de racha, FSRS, recordatorio inteligente, informe semanal, métricas y gateway de IA. */
class NextLevelTest extends TestCase
{
    use RefreshDatabase;

    private function today(): CarbonImmutable
    {
        return CarbonImmutable::today(config('vocab.timezone'));
    }

    private function word(int $i = 1): Word
    {
        return Word::create(['word' => "word{$i}", 'rank' => $i, 'source' => 'ngsl', 'translation' => "palabra {$i}"]);
    }

    // ── Protector de racha ──────────────────────────────────────────

    public function test_one_missed_day_is_covered_by_a_freeze_and_the_streak_continues(): void
    {
        $srs = app(SrsService::class);
        $user = User::factory()->create(['streak' => 5, 'streak_freezes' => 1, 'last_study_day' => $this->today()->subDays(2)->toDateString()]);

        // Faltó ayer: la racha sigue viva gracias al protector.
        $this->assertSame(5, $srs->stats($user)['streak']);
        $this->assertTrue($srs->stats($user)['streak_protected']);

        $srs->markStudied($user, $this->today());
        $user->refresh();
        $this->assertSame(6, $user->streak);
        $this->assertSame(0, $user->streak_freezes);
    }

    public function test_without_freezes_a_missed_day_resets_the_streak(): void
    {
        $srs = app(SrsService::class);
        $user = User::factory()->create(['streak' => 5, 'streak_freezes' => 0, 'last_study_day' => $this->today()->subDays(2)->toDateString()]);

        $this->assertSame(0, $srs->stats($user)['streak']);
        $srs->markStudied($user, $this->today());
        $this->assertSame(1, $user->fresh()->streak);
    }

    public function test_two_missed_days_need_two_freezes(): void
    {
        $srs = app(SrsService::class);
        $user = User::factory()->create(['streak' => 9, 'streak_freezes' => 1, 'last_study_day' => $this->today()->subDays(3)->toDateString()]);

        $srs->markStudied($user, $this->today());
        $user->refresh();
        $this->assertSame(1, $user->streak);
        $this->assertSame(1, $user->streak_freezes);   // no se gastó: no alcanzaba
    }

    public function test_a_new_freeze_is_earned_every_seven_days_up_to_two(): void
    {
        $srs = app(SrsService::class);
        $user = User::factory()->create(['streak' => 6, 'streak_freezes' => 1, 'last_study_day' => $this->today()->subDay()->toDateString()]);

        $srs->markStudied($user, $this->today());
        $this->assertSame(2, $user->fresh()->streak_freezes);

        $user->forceFill(['streak' => 13, 'last_study_day' => $this->today()->toDateString()])->save();
        $srs->markStudied($user->fresh(), $this->today()->addDay());
        $this->assertSame(2, $user->fresh()->streak_freezes);   // tope de 2
    }

    // ── FSRS ────────────────────────────────────────────────────────

    public function test_fsrs_math_matches_the_reference_values(): void
    {
        $f = new Fsrs;
        $this->assertSame(['stability' => 3.7145, 'difficulty' => 5.1618], $f->first('good'));
        $this->assertSame(4, $f->interval(3.7145));            // al 90 % de retención: intervalo ≈ estabilidad
        $this->assertEqualsWithDelta(0.9, $f->retrievability(10, 10), 0.0001);

        $good = $f->next(3.7145, 5.1618, 4, 'good');
        $this->assertGreaterThan(3.7145 * 2, $good['stability']);   // acertar a tiempo multiplica la memoria
        $again = $f->next(3.7145, 5.1618, 4, 'again');
        $this->assertLessThan(3.7145, $again['stability']);
        $this->assertGreaterThan(5.1618, $again['difficulty']);
        $easy = $f->next(3.7145, 5.1618, 4, 'easy');
        $hard = $f->next(3.7145, 5.1618, 4, 'hard');
        $this->assertTrue($hard['stability'] < $good['stability'] && $good['stability'] < $easy['stability']);
    }

    public function test_reviews_use_fsrs_and_store_the_memory_of_the_word(): void
    {
        config(['vocab.srs' => 'fsrs']);
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $word = $this->word();
        $uw = UserWord::create(['user_id' => $user->id, 'word_id' => $word->id, 'level' => 0, 'introduced_at' => $this->today()->subDay(), 'next_review' => $this->today()]);

        $this->postJson("/api/words/{$word->id}/review", ['grade' => 'good'])->assertOk();

        $uw->refresh();
        $this->assertEqualsWithDelta(3.7145, $uw->stability, 0.001);
        $this->assertSame($this->today()->addDays(4)->toDateString(), $uw->next_review->toDateString());
        $this->assertSame($this->today()->toDateString(), $uw->last_reviewed_on->toDateString());
        $this->assertSame(1, $uw->level);   // 3.7 días ≥ 3 → nivel 1 de los clásicos
    }

    public function test_old_words_without_fsrs_data_start_from_their_level(): void
    {
        config(['vocab.srs' => 'fsrs']);
        $user = User::factory()->create();
        $uw = UserWord::create(['user_id' => $user->id, 'word_id' => $this->word()->id, 'level' => 3, 'reviews' => 4, 'introduced_at' => $this->today()->subDays(30), 'next_review' => $this->today()]);

        app(SrsService::class)->review($user, $uw, 'good');

        // Nivel 3 = 15 días; acertar a tiempo la aleja bastante más.
        $this->assertGreaterThan(15, $uw->fresh()->stability);
        $this->assertGreaterThan(15, (int) round($this->today()->diffInDays($uw->fresh()->next_review)));
    }

    public function test_classic_mode_still_works_as_before(): void
    {
        config(['vocab.srs' => 'classic']);
        $user = User::factory()->create();
        $uw = UserWord::create(['user_id' => $user->id, 'word_id' => $this->word()->id, 'level' => 1, 'reviews' => 1, 'introduced_at' => $this->today()->subDays(3), 'next_review' => $this->today()]);

        app(SrsService::class)->review($user, $uw, 'good');

        $this->assertSame(2, $uw->fresh()->level);
        $this->assertSame($this->today()->addDays(7)->toDateString(), $uw->fresh()->next_review->toDateString());
        $this->assertNull($uw->fresh()->stability);
    }

    // ── Recordatorio inteligente ────────────────────────────────────

    private function practicedAt(User $user, array $utcTimes): void
    {
        foreach ($utcTimes as $i => $t) {
            DB::table('xp_days')->insert(['user_id' => $user->id, 'day' => "2026-11-0{$i}", 'xp' => 10, 'created_at' => $t, 'updated_at' => $t]);
        }
    }

    public function test_usual_time_is_the_median_start_time_in_the_users_timezone(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-11-06 12:00', 'UTC'));
        $user = User::factory()->create(['timezone' => 'America/New_York', 'reminder_auto' => true]);
        $svc = app(ReminderService::class);

        $this->practicedAt($user, [1 => '2026-11-01 01:00:00', 2 => '2026-11-02 01:10:00']);
        $this->assertNull($svc->usualTime($user));   // menos de 3 días: aún no

        // 20:00, 20:10 y 21:05 en Nueva York (UTC-5 desde el 2-nov)
        DB::table('xp_days')->where('user_id', $user->id)->delete();
        $this->practicedAt($user, [1 => '2026-11-03 01:00:00', 2 => '2026-11-04 01:10:00', 3 => '2026-11-05 02:05:00']);
        $this->assertSame('20:15', $svc->usualTime($user));
        $this->assertSame('20:45', $svc->sendTime($user));   // +30 min de margen
    }

    public function test_auto_reminder_goes_out_at_the_usual_time_and_names_the_word(): void
    {
        Notification::fake();
        $this->travelTo(CarbonImmutable::parse('2026-11-06 12:00', 'UTC'));
        $user = User::factory()->create(['reminder_enabled' => true, 'reminder_auto' => true, 'reminder_time' => '09:00', 'timezone' => 'America/New_York']);
        $user->updatePushSubscription('https://push.example.com/sub/abc', 'p256dh-key', 'auth-token', 'aes128gcm');
        $this->practicedAt($user, [1 => '2026-11-03 01:00:00', 2 => '2026-11-04 01:10:00', 3 => '2026-11-05 02:05:00']);
        $word = $this->word();
        UserWord::create(['user_id' => $user->id, 'word_id' => $word->id, 'level' => 1, 'introduced_at' => '2026-11-01', 'next_review' => '2026-11-05']);

        $this->travelTo(CarbonImmutable::parse('2026-11-06 09:05', 'America/New_York'));
        $this->artisan('reminders:send');
        Notification::assertNothingSent();   // ya no a las 09:00: aprende su hora

        $this->travelTo(CarbonImmutable::parse('2026-11-06 20:50', 'America/New_York'));
        $this->artisan('reminders:send');
        Notification::assertSentTo($user, StudyReminder::class, fn (StudyReminder $n) => str_contains($n->body(), '«word1»'));
    }

    public function test_reminder_settings_accept_auto_and_old_apps_keep_working(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->putJson('/api/reminders', ['enabled' => true, 'time' => '19:00', 'timezone' => 'America/New_York', 'auto' => true])
            ->assertOk()->assertJsonPath('reminder.auto', true);
        // Una app sin la opción nueva no la apaga.
        $this->putJson('/api/reminders', ['enabled' => true, 'time' => '18:00', 'timezone' => 'America/New_York'])
            ->assertOk()->assertJsonPath('reminder.auto', true)->assertJsonPath('reminder.time', '18:00');
    }

    // ── Informe semanal de fluidez ──────────────────────────────────

    public function test_weekly_report_compares_this_week_with_the_last_one(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $t = $this->today();
        SpeakingSession::create(['user_id' => $user->id, 'day' => $t->subDays(1), 'turns' => 5, 'words' => 120, 'speech_ms' => 60000, 'reaction_ms' => 6000, 'reaction_turns' => 3]);
        SpeakingSession::create(['user_id' => $user->id, 'day' => $t->subDays(9), 'turns' => 3, 'words' => 40, 'speech_ms' => 30000]);
        SpeakingMistake::create(['user_id' => $user->id, 'said' => 'I have 30 years', 'correct' => 'I am 30', 'next_review' => $t, 'mastered_on' => $t]);
        $other = User::factory()->create();
        SpeakingSession::create(['user_id' => $other->id, 'day' => $t, 'turns' => 9, 'words' => 900, 'speech_ms' => 600000]);

        $this->getJson('/api/speaking/weekly')->assertOk()
            ->assertJsonPath('now.minutes', 1)
            ->assertJsonPath('now.wpm', 120)
            ->assertJsonPath('now.reaction', 2)
            ->assertJsonPath('now.mistakes_mastered', 1)
            ->assertJsonPath('before.minutes', 0.5)
            ->assertJsonPath('before.wpm', 80)
            ->assertJsonPath('conquered.0.correct', 'I am 30');
    }

    // ── Métricas para el panel ──────────────────────────────────────

    public function test_metrics_snapshot_counts_active_users_and_retention_without_demo(): void
    {
        $t = $this->today();
        $a = User::factory()->create();
        $b = User::factory()->create();
        $demo = User::factory()->create(['email' => 'x@'.\App\Services\DemoService::DOMAIN]);
        $xp = fn ($u, $d, $s = 1) => DB::table('xp_days')->insert(['user_id' => $u->id, 'day' => $t->subDays($d)->toDateString(), 'xp' => 10, 'sessions' => $s, 'created_at' => now()]);
        $xp($a, 3); $xp($a, 2); $xp($a, 0, 2);   // volvió al día siguiente
        $xp($b, 3);                               // no volvió
        $xp($demo, 0, 5);

        $m = (new \App\Console\Commands\MetricsSnapshot)->compute($t);

        $this->assertSame(2, $m['users']);
        $this->assertSame(1, $m['active_today']);
        $this->assertSame(2, $m['active_7d']);
        $this->assertSame(2, $m['sessions_today']);
        $this->assertSame(['percent' => 50, 'of' => 2], $m['retention_d1']);
        $this->assertCount(14, $m['daily']);
    }

    // ── Gateway de IA del panel ─────────────────────────────────────

    public function test_ai_goes_through_the_panel_gateway_when_the_key_is_set(): void
    {
        config(['vocab.ai_gateway.key' => 'test-gateway-key', 'vocab.anthropic.key' => null]);
        Http::fake(['127.0.0.1:8000/api/ai/chat' => Http::response(['reply' => "uno\ndos\ntres"])]);

        $lines = app(ClaudeService::class)->suggestAid('clothes', 'ropa');

        $this->assertSame(['uno', 'dos', 'tres'], $lines);
        Http::assertSent(fn (HttpRequest $r) => $r->hasHeader('Authorization', 'Bearer test-gateway-key')
            && $r['agent'] === 'w2w'
            && str_contains($r['message'], '<instructions>'));
        Http::assertNotSent(fn (HttpRequest $r) => str_contains($r->url(), 'anthropic.com'));
    }

    public function test_if_the_gateway_is_down_it_falls_back_to_the_direct_key(): void
    {
        config(['vocab.ai_gateway.key' => 'k', 'vocab.anthropic.key' => 'direct']);
        Http::fake([
            '127.0.0.1:8000/*' => Http::response(['message' => 'down'], 503),
            'api.anthropic.com/*' => Http::response(['content' => [['type' => 'text', 'text' => "a\nb\nc"]]]),
        ]);
        $this->assertSame(['a', 'b', 'c'], app(ClaudeService::class)->suggestAid('x', 'y'));
    }

    public function test_the_gateway_daily_limit_is_not_skipped_with_the_direct_key(): void
    {
        config(['vocab.ai_gateway.key' => 'k', 'vocab.anthropic.key' => 'direct']);
        Http::fake([
            '127.0.0.1:8000/*' => Http::response(['message' => 'limit'], 429),
            'api.anthropic.com/*' => Http::response(['content' => [['type' => 'text', 'text' => "a\nb\nc"]]]),
        ]);
        $this->expectException(\RuntimeException::class);
        app(ClaudeService::class)->suggestAid('x', 'y');
    }

    public function test_long_conversations_drop_the_oldest_turns_to_fit_the_gateway(): void
    {
        $msgs = [];
        foreach (range(1, 40) as $i) {
            $msgs[] = ['role' => $i % 2 ? 'user' : 'assistant', 'content' => str_repeat("turn{$i} ", 40)];
        }
        $out = app(ClaudeService::class)->flatten('Be a friendly tutor.', $msgs, 8000);

        $this->assertLessThanOrEqual(8000, mb_strlen($out));
        $this->assertStringContainsString('Be a friendly tutor.', $out);
        $this->assertStringContainsString('turn39', $out);    // el último turno siempre va
        $this->assertStringNotContainsString('turn1 ', $out);
    }
}
