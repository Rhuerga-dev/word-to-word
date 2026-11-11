<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Oído: reconocer de oído las palabras aprendidas, por escalones de menos a más difícil. */
class EarTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create(['cefr_level' => 'B1', 'daily_new' => 10]);
        Sanctum::actingAs($this->user);
        // Palabras para opciones y sonidos parecidos.
        foreach (['thing', 'think', 'sink', 'thin', 'rent', 'tent', 'bent'] as $i => $w) {
            Word::firstOrCreate(['word' => $w], ['rank' => 100 + $i, 'translation' => 'x']);
        }
    }

    private function learned(string $word, array $extra = [], int $level = 0): Word
    {
        $w = Word::updateOrCreate(['word' => $word], ['rank' => random_int(1, 2000), 'translation' => 'tr', 'example' => "I use *{$word}* a lot."] + $extra);
        UserWord::updateOrCreate(['user_id' => $this->user->id, 'word_id' => $w->id], ['introduced_at' => today(config('vocab.timezone')), 'next_review' => today()->addDays(3), 'ear_level' => $level]);

        return $w;
    }

    private function earFor(string $word): array
    {
        return collect($this->getJson('/api/session/today')->assertOk()->json('plan.ear'))->firstWhere('word', $word);
    }

    public function test_escalon_0_el_sonido_eliges_la_palabra_escrita(): void
    {
        $this->learned('think', ['gloss' => 'use your mind', 'emoji' => '🤔', 'definition_easy' => 'use your head to have ideas']);
        $e = $this->earFor('think');
        $this->assertSame('sound', $e['mode']);
        $this->assertContains('think', $e['options']);
        $this->assertSame('think', $e['options'][$e['answer']]);
        $this->assertCount(3, array_unique($e['options']));
        $this->assertTrue($e['audio'][0]['slow']);
    }

    public function test_escalon_1_significado_facil_con_emoji(): void
    {
        $this->learned('rent', ['gloss' => 'money for a house', 'emoji' => '🏠', 'definition_easy' => 'money you pay each month to live in a place'], 1);
        $this->learned('invoice', ['gloss' => 'paper with price', 'emoji' => '🧾']);
        $this->learned('deadline', ['gloss' => 'last day']);
        $e = $this->earFor('rent');
        $this->assertSame('easy', $e['mode']);
        $this->assertSame('🏠 money for a house', $e['options'][$e['answer']]);
    }

    public function test_escalon_2_definicion_facil_y_3_en_una_frase(): void
    {
        $this->learned('rent', ['definition' => 'a regular payment for the use of property', 'definition_easy' => 'money you pay each month to live in a place'], 2);
        $this->learned('invoice', ['definition_easy' => 'a paper that says how much to pay']);
        $this->learned('deadline', ['definition_easy' => 'the last day to finish work']);
        $e = $this->earFor('rent');
        $this->assertSame('definition', $e['mode']);
        $this->assertSame('money you pay each month to live in a place', $e['options'][$e['answer']]);

        UserWord::whereHas('word', fn ($q) => $q->where('word', 'rent'))->update(['ear_level' => 3]);
        $e = $this->earFor('rent');
        $this->assertSame('sentence', $e['mode']);
        $this->assertSame('I use rent a lot.', $e['audio'][0]['text']);
        $this->assertSame('rent', $e['audio'][1]['text']);
    }

    public function test_sube_rapido_baja_un_escalon_si_fallas_y_lento_no_sube(): void
    {
        $w = $this->learned('rent', ['gloss' => 'money for a house'], 2);
        $r = $this->postJson("/api/words/{$w->id}/ear", ['ok' => true, 'ms' => 1500])->assertOk();
        $r->assertJsonPath('ear_level', 3)->assertJsonPath('fast', true)->assertJsonPath('mode', 'sentence');
        $this->assertGreaterThan(0, $r->json('xp_gained'));

        $this->postJson("/api/words/{$w->id}/ear", ['ok' => true, 'ms' => 9000])->assertJsonPath('ear_level', 3)->assertJsonPath('fast', false)->assertJsonPath('xp_gained', 0);
        $this->postJson("/api/words/{$w->id}/ear", ['ok' => false, 'ms' => 900])->assertJsonPath('ear_level', 2);
    }

    public function test_en_el_escalon_4_hay_que_contestar_en_2_segundos_y_luego_es_automatica(): void
    {
        $w = $this->learned('rent', ['gloss' => 'money for a house'], 4);
        $this->postJson("/api/words/{$w->id}/ear", ['ok' => true, 'ms' => 2500])->assertJsonPath('fast', false)->assertJsonPath('ear_level', 4);
        $this->postJson("/api/words/{$w->id}/ear", ['ok' => true, 'ms' => 1500])->assertJsonPath('ear_level', 5)
            ->assertJsonPath('automatic', true)->assertJsonPath('automatic_total', 1);
        $this->getJson('/api/stats')->assertJsonPath('ear_automatic', 1);
    }

    public function test_tocar_una_palabra_de_la_definicion_da_su_significado_simple(): void
    {
        Word::create(['word' => 'payment', 'rank' => 900, 'translation' => 'pago', 'gloss' => 'money you give', 'emoji' => '💵']);
        $this->getJson('/api/words/lookup?w=payment,')->assertOk()->assertJsonPath('gloss', 'money you give')->assertJsonPath('emoji', '💵');
        $this->getJson('/api/words/lookup?w=payments')->assertOk()->assertJsonPath('word', 'payment');
        $this->getJson('/api/words/lookup?w=zzzz')->assertNotFound();
    }

    public function test_si_la_palabra_aun_no_tiene_significado_facil_la_ia_lo_escribe_al_tocarla(): void
    {
        config(['vocab.anthropic.key' => 'test-key']);
        Word::create(['word' => 'property', 'rank' => 950, 'translation' => 'propiedad']);
        Http::fake(['api.anthropic.com/*' => Http::response(['content' => [['type' => 'text', 'text' => json_encode([
            'property' => ['gloss' => 'things you own', 'emoji' => '🏡', 'easy' => 'a house or land that is yours'],
        ])]]])]);
        $this->getJson('/api/words/lookup?w=property')->assertOk()->assertJsonPath('gloss', 'things you own');
        $this->assertSame('things you own', Word::where('word', 'property')->value('gloss'));
    }

    public function test_solo_palabras_que_ya_aprendiste(): void
    {
        $w = Word::create(['word' => 'other', 'rank' => 10, 'translation' => 'otro']);
        $this->postJson("/api/words/{$w->id}/ear", ['ok' => true, 'ms' => 1000])->assertNotFound();
        $this->postJson("/api/words/{$w->id}/ear", ['ok' => 'x'])->assertUnprocessable();
    }

    public function test_la_ia_escribe_los_significados_faciles_sin_delatar_la_palabra(): void
    {
        config(['vocab.anthropic.key' => 'test-key']);
        $this->learned('rent');
        $this->learned('invoice');
        Http::fake(['api.anthropic.com/*' => Http::response(['content' => [['type' => 'text', 'text' => json_encode([
            'rent' => ['gloss' => 'money for a house', 'emoji' => '🏠', 'easy' => 'money you pay to live in a place'],
            'invoice' => ['gloss' => 'an invoice paper', 'emoji' => null, 'easy' => 'a paper that says how much to pay'],
        ])]]])]);

        $this->artisan('words:simplify')->assertSuccessful();

        $rent = Word::where('word', 'rent')->first();
        $this->assertSame('money for a house', $rent->gloss);
        $this->assertSame('🏠', $rent->emoji);
        $inv = Word::where('word', 'invoice')->first();
        $this->assertSame('', $inv->gloss); // decía la palabra: se descarta y no se reintenta
        $this->assertSame('a paper that says how much to pay', $inv->definition_easy);
    }
}
