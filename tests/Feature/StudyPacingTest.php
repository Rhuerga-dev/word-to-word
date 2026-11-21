<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Ritmo de estudio: (1) con muchos repasos atrasados no entran palabras nuevas;
 * (2) una palabra olvidada vuelve hoy mismo, hasta que salga.
 */
class StudyPacingTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create(['cefr_level' => null, 'daily_new' => 10]);
        Sanctum::actingAs($this->user);
    }

    private function day(int $offset = 0): string
    {
        return today(config('vocab.timezone'))->addDays($offset)->toDateString();
    }

    private function word(int $i): Word
    {
        return Word::create(['word' => "word{$i}", 'rank' => $i, 'source' => 'ngsl', 'translation' => "palabra {$i}", 'example' => "A *word{$i}* here."]);
    }

    /** $n palabras ya aprendidas cuyo repaso toca hoy o antes. */
    private function due(int $n, int $from = 1): void
    {
        for ($i = $from; $i < $from + $n; $i++) {
            UserWord::create(['user_id' => $this->user->id, 'word_id' => $this->word($i)->id, 'level' => 1,
                'next_review' => $this->day(-1), 'introduced_at' => $this->day(-5)]);
        }
    }

    private function fresh(int $n): void
    {
        for ($i = 1000; $i < 1000 + $n; $i++) {
            $this->word($i);
        }
    }

    // ---------- Freno de palabras nuevas ----------

    public function test_con_pocos_repasos_atrasados_siguen_entrando_palabras_nuevas(): void
    {
        config(['vocab.new_pause_reviews' => 20]);
        $this->due(20);          // justo en el límite: todavía no frena
        $this->fresh(5);

        $today = $this->getJson('/api/today')->assertOk()->assertJsonPath('new_paused', false)->assertJsonPath('reviews_due', 20);
        $this->assertCount(5, collect($today->json('cards'))->where('mode', 'new'));
        $this->getJson('/api/session/today')->assertOk()->assertJsonPath('new_paused', false)->assertJsonCount(3, 'plan.new');
    }

    public function test_con_muchos_repasos_atrasados_no_entran_palabras_nuevas(): void
    {
        config(['vocab.new_pause_reviews' => 20]);
        $this->due(21);
        $this->fresh(5);

        $today = $this->getJson('/api/today')->assertOk()->assertJsonPath('new_paused', true)->assertJsonPath('reviews_due', 21);
        $this->assertCount(0, collect($today->json('cards'))->where('mode', 'new'));
        $this->assertCount(21, collect($today->json('cards'))->where('mode', 'review'), 'los repasos siguen ahí');
        $this->getJson('/api/session/today')->assertOk()->assertJsonPath('new_paused', true)->assertJsonPath('reviews_due', 21)->assertJsonPath('new_pause_at', 20)->assertJsonCount(0, 'plan.new')->assertJsonCount(5, 'plan.reviews');
    }

    public function test_al_ponerse_al_dia_vuelven_las_palabras_nuevas(): void
    {
        config(['vocab.new_pause_reviews' => 20]);
        $this->due(21);
        $this->fresh(5);
        $this->getJson('/api/today')->assertJsonPath('new_paused', true);

        $one = UserWord::where('user_id', $this->user->id)->first();
        $this->postJson("/api/words/{$one->word_id}/review", ['grade' => 'good'])->assertOk();

        $today = $this->getJson('/api/today')->assertJsonPath('new_paused', false)->assertJsonPath('reviews_due', 20);
        $this->assertCount(5, collect($today->json('cards'))->where('mode', 'new'));
    }

    public function test_el_freno_se_puede_apagar(): void
    {
        config(['vocab.new_pause_reviews' => 0]);
        $this->due(40);
        $this->fresh(5);
        $today = $this->getJson('/api/today')->assertOk()->assertJsonPath('new_paused', false);
        $this->assertCount(5, collect($today->json('cards'))->where('mode', 'new'));
    }

    public function test_con_el_freno_brainy_manda_a_repasar_en_vez_de_a_palabras_nuevas(): void
    {
        config(['vocab.new_pause_reviews' => 20]);
        $this->due(21);
        $this->fresh(5);
        $this->postJson('/api/pet/feed')->assertOk()->assertJsonPath('go', 'reviews');
    }

    // ---------- Una palabra olvidada vuelve hoy ----------

    public function test_una_palabra_olvidada_vuelve_hoy_mismo_y_va_al_final_de_la_cola(): void
    {
        $this->due(3);
        $first = UserWord::where('user_id', $this->user->id)->orderBy('id')->first();

        $r = $this->postJson("/api/words/{$first->word_id}/review", ['grade' => 'again'])->assertOk();
        $this->assertSame($this->day(), substr((string) $first->fresh()->next_review, 0, 10), 'pendiente para hoy, no para mañana');
        $this->assertSame(0, $r->json('previews.again'));

        $cards = collect($this->getJson('/api/today')->json('cards'))->where('mode', 'review')->values();
        $this->assertCount(3, $cards, 'sigue en la cola de hoy');
        $this->assertSame($first->word_id, $cards->last()['id'], 'después de las que llevaban más tiempo esperando');
    }

    public function test_al_acertarla_despues_ya_sale_de_la_cola_y_no_gana_memoria_de_regalo(): void
    {
        $this->due(1);
        $uw = UserWord::where('user_id', $this->user->id)->first();

        $this->postJson("/api/words/{$uw->word_id}/review", ['grade' => 'again'])->assertOk();
        $afterFail = $uw->fresh();
        $this->postJson("/api/words/{$uw->word_id}/review", ['grade' => 'good'])->assertOk();
        $afterGood = $uw->fresh();

        $this->assertGreaterThanOrEqual($this->day(1), substr((string) $afterGood->next_review, 0, 10), 'ya no toca hoy');
        // Repasar el mismo día no «demuestra» memoria: la estabilidad no crece por acertar a los cinco minutos.
        $this->assertEqualsWithDelta($afterFail->stability, $afterGood->stability, 0.001);
        $this->assertSame([2, 1], [$afterGood->reviews, $afterGood->fails]);
        $this->assertCount(0, collect($this->getJson('/api/today')->json('cards'))->where('mode', 'review'));
    }

    public function test_tambien_en_el_metodo_clasico(): void
    {
        config(['vocab.srs' => 'classic']);
        $this->due(1);
        $uw = UserWord::where('user_id', $this->user->id)->first();
        $this->postJson("/api/words/{$uw->word_id}/review", ['grade' => 'again'])->assertOk();
        $this->assertSame($this->day(), substr((string) $uw->fresh()->next_review, 0, 10));
        $this->assertSame(0, $uw->fresh()->level);
    }

    public function test_se_puede_volver_a_manana_desde_la_configuracion(): void
    {
        config(['vocab.relearn_same_day' => false]);
        $this->due(1);
        $uw = UserWord::where('user_id', $this->user->id)->first();
        $this->postJson("/api/words/{$uw->word_id}/review", ['grade' => 'again'])->assertOk()->assertJsonPath('previews.again', 1);
        $this->assertSame($this->day(1), substr((string) $uw->fresh()->next_review, 0, 10));
    }
}
