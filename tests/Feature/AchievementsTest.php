<?php

namespace Tests\Feature;

use App\Models\SpeakingSession;
use App\Models\User;
use App\Services\LeagueService;
use App\Services\XpService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Logros calculados de datos reales y liga semanal con privacidad. */
class AchievementsTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create(['name' => 'Reynaldo Huerga', 'cefr_level' => 'B1', 'daily_new' => 10]);
        Sanctum::actingAs($this->user);
    }

    private function day(): string
    {
        return today(config('vocab.timezone'))->toDateString();
    }

    public function test_achievements_unlock_from_what_you_did_and_are_announced_once(): void
    {
        $a = $this->getJson('/api/achievements')->assertOk();
        $this->assertSame(0, $a->json('unlocked'));
        $this->assertGreaterThan(10, $a->json('total'));

        $this->postJson('/api/session/complete')->assertOk()->assertJsonPath('achievements.0.code', 'first_session');
        SpeakingSession::create(['user_id' => $this->user->id, 'day' => $this->day(), 'words' => 120, 'speech_ms' => 11 * 60000, 'long_pauses' => 0]);

        $r = $this->getJson('/api/achievements')->assertOk();
        $codes = array_column(array_filter($r->json('achievements'), fn ($x) => $x['unlocked_at']), 'code');
        $this->assertEqualsCanonicalizing(['first_session', 'speak_10', 'no_pauses'], $codes);
        // "Primer paso" ya se anunció al terminar la sesión: solo salen los otros dos.
        $this->assertEqualsCanonicalizing(['speak_10', 'no_pauses'], array_column($r->json('new'), 'code'));
        $this->assertSame([], $this->getJson('/api/achievements')->json('new'));   // el aviso sale una vez
    }

    public function test_the_league_ranks_the_week_by_points_with_first_name_and_initial(): void
    {
        $ana = User::factory()->create(['name' => 'Ana María López']);
        $hidden = User::factory()->create(['name' => 'Oculto Total']);
        $hidden->forceFill(['league_visible' => false])->save();
        $demo = User::factory()->create(['name' => 'Demo', 'email' => 'demo-x@'.\App\Services\DemoService::DOMAIN]);
        $xp = app(XpService::class);
        $xp->add($this->user, 'lab');                 // 15
        $xp->add($ana, 'lab'); $xp->add($ana, 'lab'); // 30
        $xp->add($hidden, 'lab'); $xp->add($hidden, 'lab'); $xp->add($hidden, 'lab');
        $xp->add($demo, 'lab'); $xp->add($demo, 'lab'); $xp->add($demo, 'lab');

        $l = $this->getJson('/api/league')->assertOk();
        $l->assertJsonPath('me.rank', 2)->assertJsonPath('me.xp', 15)->assertJsonPath('players', 2)
            ->assertJsonPath('top.0.name', 'Ana M.')->assertJsonPath('top.1.name', 'Reynaldo H.')->assertJsonPath('top.1.me', true);
        $this->assertStringNotContainsString('@', json_encode($l->json('top')));
    }

    public function test_you_can_hide_from_the_league_but_still_see_your_rank(): void
    {
        app(XpService::class)->add($this->user, 'lab');
        $this->putJson('/api/league/visibility', ['visible' => false])->assertOk()->assertJsonPath('visible', false)->assertJsonPath('me.rank', 1);
        $other = User::factory()->create();
        Sanctum::actingAs($other);
        $this->getJson('/api/league')->assertJsonPath('players', 0);
    }

    public function test_display_names_never_show_the_full_surname(): void
    {
        $this->assertSame('Reynaldo H.', LeagueService::display('Reynaldo Huerga Pérez'));
        $this->assertSame('Ana', LeagueService::display('Ana'));
        $this->assertSame('Alumno', LeagueService::display('  '));
    }

    public function test_reset_clears_achievements(): void
    {
        $this->postJson('/api/session/complete');
        $this->postJson('/api/reset', ['password' => 'password'])->assertNoContent();
        $this->assertSame(0, DB::table('achievements')->where('user_id', $this->user->id)->count());
    }
}
