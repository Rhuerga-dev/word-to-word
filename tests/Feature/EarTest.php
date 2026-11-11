<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Oído: reconocer de oído las palabras aprendidas, rápido. Es el primer paso de la sesión de Hoy. */
class EarTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create(['cefr_level' => 'B1', 'daily_new' => 10]);
        Sanctum::actingAs($this->user);
    }

    private function learned(string $word, string $tr, ?string $def = null): Word
    {
        $w = Word::create(['word' => $word, 'rank' => random_int(1, 2000), 'translation' => $tr, 'definition' => $def, 'example' => "I use *{$word}* a lot."]);
        UserWord::create(['user_id' => $this->user->id, 'word_id' => $w->id, 'introduced_at' => today(config('vocab.timezone')), 'next_review' => today()->addDays(3)]);

        return $w;
    }

    public function test_la_sesion_empieza_por_el_oido_con_tres_opciones(): void
    {
        $this->learned('invoice', 'factura', 'a document that says how much to pay');
        $this->learned('deadline', 'fecha límite', 'the last day to finish something');
        $this->learned('rent', 'alquiler', 'money you pay to live in a place');
        Word::create(['word' => 'notlearned', 'rank' => 50, 'translation' => 'no']);

        $ear = $this->getJson('/api/session/today')->assertOk()->json('plan.ear');
        $this->assertCount(3, $ear);
        $first = $ear[0];
        $this->assertCount(3, $first['options']);
        $this->assertSame(count(array_unique($first['options'])), 3);
        $this->assertNotContains('notlearned', array_column($ear, 'word'));
        // Escalón 1 (A2/B1 sin promoción → 2 en B1): con B1 el significado va en inglés.
        $this->assertContains('a document that says how much to pay', collect($ear)->firstWhere('word', 'invoice')['options']);
    }

    public function test_rapido_y_bien_sube_y_vuelve_mas_tarde(): void
    {
        $w = $this->learned('invoice', 'factura', 'a document that says how much to pay');
        $r = $this->postJson("/api/words/{$w->id}/ear", ['ok' => true, 'ms' => 1500])->assertOk();
        $r->assertJsonPath('ear_level', 1)->assertJsonPath('fast', true);
        $this->assertGreaterThan(0, $r->json('xp_gained'));
        $this->assertSame(today(config('vocab.timezone'))->addDay()->toDateString(), $r->json('next'));

        $this->postJson("/api/words/{$w->id}/ear", ['ok' => true, 'ms' => 1200])->assertJsonPath('ear_level', 2)
            ->assertJsonPath('next', today(config('vocab.timezone'))->addDays(3)->toDateString());
        // Ya no sale hoy en la sesión.
        $this->assertEmpty($this->getJson('/api/session/today')->json('plan.ear'));
    }

    public function test_lento_no_sube_y_mal_baja_a_cero(): void
    {
        $w = $this->learned('deadline', 'fecha límite', 'the last day to finish something');
        UserWord::where('word_id', $w->id)->update(['ear_level' => 2]);

        $this->postJson("/api/words/{$w->id}/ear", ['ok' => true, 'ms' => 6000])->assertJsonPath('ear_level', 2)->assertJsonPath('fast', false)->assertJsonPath('xp_gained', 0);
        $this->postJson("/api/words/{$w->id}/ear", ['ok' => false, 'ms' => 900])->assertJsonPath('ear_level', 0);
    }

    public function test_tres_veces_rapido_es_automatica_y_cuenta_en_las_estadisticas(): void
    {
        $w = $this->learned('rent', 'alquiler', 'money you pay to live in a place');
        foreach ([1, 2, 3] as $i) {
            $r = $this->postJson("/api/words/{$w->id}/ear", ['ok' => true, 'ms' => 1000]);
        }
        $r->assertJsonPath('automatic', true)->assertJsonPath('automatic_total', 1);
        $this->getJson('/api/stats')->assertJsonPath('ear_automatic', 1);
    }

    public function test_solo_palabras_que_ya_aprendiste(): void
    {
        $w = Word::create(['word' => 'other', 'rank' => 10, 'translation' => 'otro']);
        $this->postJson("/api/words/{$w->id}/ear", ['ok' => true, 'ms' => 1000])->assertNotFound();
        $this->postJson("/api/words/{$w->id}/ear", ['ok' => 'x'])->assertUnprocessable();
    }
}
