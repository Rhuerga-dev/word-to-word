<?php

namespace Tests\Feature;

use App\Models\User;
use App\Notifications\BrainyAlert;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Avisos de Brainy en la web (push del servidor): solo si el alumno los activó, nunca de noche,
 * como mucho 2 al día separados 3 h, y uno por ausencia (no insiste si no volvió a cuidarla).
 */
class PetWebAlertsTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        Notification::fake();
        $this->at('2026-11-20 12:00');
        $this->user = User::factory()->create(['cefr_level' => 'B1', 'timezone' => config('vocab.timezone')]);
        $this->user->updatePushSubscription('https://fcm.googleapis.com/fcm/send/abc', 'key', 'auth');
        Sanctum::actingAs($this->user);
    }

    private function at(string $local): void
    {
        $this->travelTo(CarbonImmutable::parse($local, config('vocab.timezone')));
    }

    /** Brainy con hambre: la comida a 0,5 corazones desde ahora. */
    private function hungry(): void
    {
        $this->getJson('/api/pet')->assertOk();   // crea la mascota
        DB::table('pets')->where('user_id', $this->user->id)->update(['food' => 0.5, 'food_at' => now(), 'joy' => 4, 'joy_at' => now()]);
    }

    private function run_(): void
    {
        $this->artisan('pet:alerts')->assertSuccessful();
    }

    public function test_activar_y_desactivar_los_avisos(): void
    {
        $this->getJson('/api/pet')->assertOk()->assertJsonPath('web_alerts', false);
        $this->putJson('/api/pet/alerts', ['enabled' => true])->assertOk()->assertJsonPath('web_alerts', true);
        $this->putJson('/api/pet/alerts', ['enabled' => false])->assertOk()->assertJsonPath('web_alerts', false);
        $this->putJson('/api/pet/alerts', ['enabled' => 'quizá'])->assertUnprocessable();
    }

    public function test_sin_activarlos_no_avisa(): void
    {
        $this->hungry();
        $this->run_();
        Notification::assertNothingSent();
    }

    public function test_avisa_si_tiene_hambre_y_no_insiste(): void
    {
        $this->hungry();
        $this->putJson('/api/pet/alerts', ['enabled' => true])->assertOk();
        $this->run_();
        Notification::assertSentTo($this->user, BrainyAlert::class, fn ($n) => $n->kind === 'hungry' && str_contains($n->title(), 'tiene hambre'));

        // 4 horas después sigue con hambre, pero no volvió a cuidarla: no insiste.
        $this->at('2026-11-20 16:00');
        $this->run_();
        Notification::assertSentToTimes($this->user, BrainyAlert::class, 1);

        // Volvió (la cuidó) y otra vez tiene hambre, ya pasadas 3 h: segundo aviso del día.
        DB::table('pets')->where('user_id', $this->user->id)->update(['last_care_at' => now(), 'food' => 0.5, 'food_at' => now()]);
        $this->at('2026-11-20 16:10');
        $this->run_();
        Notification::assertSentToTimes($this->user, BrainyAlert::class, 2);

        // Un tercero ese día, no (máximo 2).
        DB::table('pets')->where('user_id', $this->user->id)->update(['last_care_at' => now(), 'food' => 0.5, 'food_at' => now()]);
        $this->at('2026-11-20 19:30');
        $this->run_();
        Notification::assertSentToTimes($this->user, BrainyAlert::class, 2);
    }

    public function test_nunca_de_noche(): void
    {
        $this->at('2026-11-20 21:30');
        $this->hungry();
        $this->putJson('/api/pet/alerts', ['enabled' => true])->assertOk();
        $this->run_();
        $this->at('2026-11-21 07:00');
        $this->run_();
        Notification::assertNothingSent();
    }

    public function test_sin_suscripcion_del_navegador_no_avisa(): void
    {
        $this->hungry();
        $this->putJson('/api/pet/alerts', ['enabled' => true])->assertOk();
        $this->user->pushSubscriptions()->delete();
        $this->run_();
        Notification::assertNothingSent();
    }

    public function test_texto_de_ganas_de_jugar(): void
    {
        $n = new BrainyAlert('bored', 'Pepa');
        $this->assertSame('Pepa quiere jugar', $n->title());
        $this->assertStringContainsString('Oído', $n->body());
    }
}
