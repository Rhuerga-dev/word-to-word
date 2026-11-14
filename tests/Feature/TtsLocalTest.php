<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Voz local Kokoro: se usa si está encendida; si no, Azure. Se puede forzar una u otra para comparar. */
class TtsLocalTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        config(['vocab.azure_speech.key' => 'az-key', 'vocab.tts.local_url' => 'http://127.0.0.1:8880']);
        Sanctum::actingAs(User::factory()->create());
    }

    private function tts(array $q = [])
    {
        return $this->get('/api/tts?'.http_build_query($q + ['text' => 'Hello there', 'lang' => 'en']));
    }

    public function test_the_local_voice_is_used_when_it_is_on(): void
    {
        Http::fake(['127.0.0.1:8880/health' => Http::response(['ok' => true]), '127.0.0.1:8880/tts' => Http::response('LOCALMP3'), '*' => Http::response('AZUREMP3')]);
        $this->tts()->assertOk();
        Http::assertSent(fn (HttpRequest $r) => str_ends_with($r->url(), '/tts') && $r['text'] === 'Hello there' && $r['lang'] === 'en');
        Http::assertNotSent(fn (HttpRequest $r) => str_contains($r->url(), 'microsoft.com'));
    }

    public function test_when_the_local_voice_is_off_azure_answers(): void
    {
        Http::fake(['127.0.0.1:8880/*' => Http::response('', 500), '*' => Http::response('AZUREMP3')]);
        $this->tts()->assertOk();
        Http::assertSent(fn (HttpRequest $r) => str_contains($r->url(), 'tts.speech.microsoft.com'));
    }

    public function test_each_voice_can_be_chosen_to_compare(): void
    {
        Http::fake(['127.0.0.1:8880/health' => Http::response(['ok' => true]), '127.0.0.1:8880/tts' => Http::response('LOCALMP3'), '*' => Http::response('AZUREMP3')]);
        $this->tts(['provider' => 'azure'])->assertOk();
        Http::assertSent(fn (HttpRequest $r) => str_contains($r->url(), 'microsoft.com'));
        $this->tts(['provider' => 'nope'])->assertStatus(422);   // la API siempre responde JSON
    }

    public function test_asking_for_the_local_voice_while_it_is_off_fails_instead_of_faking_it(): void
    {
        Http::fake(['127.0.0.1:8880/*' => Http::response('', 500), '*' => Http::response('AZUREMP3')]);
        $this->tts(['provider' => 'kokoro'])->assertStatus(502);
    }

    public function test_si_azure_no_responde_no_se_vuelve_a_esperar_durante_un_minuto(): void
    {
        $azureCalls = 0;
        Http::fake(function (HttpRequest $r) use (&$azureCalls) {
            if (str_contains($r->url(), '127.0.0.1:8880')) {
                throw new \Illuminate\Http\Client\ConnectionException('local apagado');
            }
            $azureCalls++;
            throw new \Illuminate\Http\Client\ConnectionException('Resolving timed out');
        });

        $this->tts()->assertStatus(502);
        $this->tts(['text' => 'Another phrase'])->assertStatus(502);
        $this->assertSame(1, $azureCalls);   // la segunda vez responde al momento, sin esperar a Azure

        $this->travel(61)->seconds();
        $this->tts(['text' => 'Third phrase'])->assertStatus(502);
        $this->assertSame(2, $azureCalls);
    }

    public function test_un_error_500_de_azure_tambien_lo_marca_caido(): void
    {
        Http::fake(['127.0.0.1:8880/*' => Http::response('', 500), '*' => Http::response('', 503)]);
        $this->tts()->assertStatus(502);
        $this->assertTrue(\Illuminate\Support\Facades\Cache::get('tts:azure-down'));
    }
}
