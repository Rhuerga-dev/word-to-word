<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\PronunciationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WhisperTranscribeTest extends TestCase
{
    use RefreshDatabase;

    private function wav(float $secs): string
    {
        return str_repeat("\0", 44 + (int) ($secs * 32000));
    }

    private function azureOk(): array
    {
        return ['RecognitionStatus' => 'Success', 'NBest' => [['Display' => 'From Azure.', 'Words' => []]]];
    }

    protected function setUp(): void
    {
        parent::setUp();
        config(['vocab.whisper.url' => 'http://127.0.0.1:8178', 'vocab.azure_speech.key' => 'k']);
        Cache::forget('whisper:up');
        Sanctum::actingAs(User::factory()->create());
    }

    public function test_uses_local_whisper_with_word_timings_and_does_not_pay_azure(): void
    {
        Http::fake([
            '127.0.0.1:8178/*' => Http::response(['text' => ' I think so.', 'segments' => [[
                'text' => ' I think so.', 'no_speech_prob' => 0.01, 'avg_logprob' => -0.1,
                'words' => [['word' => ' I', 'start' => 0.0, 'end' => 0.3], ['word' => ' think', 'start' => 0.3, 'end' => 0.8], ['word' => ' so', 'start' => 0.8, 'end' => 1.2], ['word' => '.', 'start' => 1.2, 'end' => 1.2]],
            ]]]),
            '*' => Http::response($this->azureOk()),
        ]);

        $r = app(PronunciationService::class)->transcribe($this->wav(3), 'en-US', freeSpeech: true);

        $this->assertSame('I think so.', $r['text']);
        $this->assertSame(3, $r['words']);
        Http::assertSent(fn (Request $q) => str_contains($q->url(), '/inference') && str_contains($q->body(), 'audio_ctx'));
        Http::assertNotSent(fn (Request $q) => str_contains($q->url(), 'microsoft.com'));
        $this->assertSame(['whisper'], DB::table('ai_usage')->pluck('provider')->all());
        $this->assertSame(0.0, (float) DB::table('ai_usage')->value('cost_usd'));
    }

    public function test_falls_back_to_azure_when_whisper_is_down_and_waits_a_minute(): void
    {
        Http::fake([
            '127.0.0.1:8178/*' => Http::response('', 500),
            '*' => Http::response($this->azureOk()),
        ]);
        $pron = app(PronunciationService::class);

        $this->assertSame('From Azure.', $pron->transcribe($this->wav(2), freeSpeech: true)['text']);
        $this->assertFalse($pron->whisperUp());   // un minuto sin volver a intentarlo
        $this->assertSame('From Azure.', $pron->transcribe($this->wav(2), freeSpeech: true)['text']);
        Http::assertSentCount(3);                 // 1 Whisper + 2 Azure
    }

    public function test_drops_invented_text_on_silence(): void
    {
        Http::fake(['127.0.0.1:8178/*' => Http::response(['text' => ' Thank you for watching.', 'segments' => [[
            'text' => ' Thank you for watching.', 'no_speech_prob' => 0.9, 'avg_logprob' => -1.2, 'words' => [],
        ]]])]);

        $this->assertSame('', app(PronunciationService::class)->transcribe($this->wav(2), freeSpeech: true)['text']);
    }

    public function test_short_graded_audio_stays_on_azure_and_long_narration_goes_local(): void
    {
        Http::fake([
            '127.0.0.1:8178/*' => Http::response(['text' => ' Local.', 'segments' => [['text' => ' Local.', 'no_speech_prob' => 0, 'avg_logprob' => -0.1, 'words' => []]]]),
            '*' => Http::response($this->azureOk()),
        ]);
        $pron = app(PronunciationService::class);

        // Repetir / órdenes (corto, se califica): Azure, igual que antes.
        $this->assertSame('From Azure.', $pron->transcribe($this->wav(4))['text']);
        // Narración (larga, habla libre): Whisper.
        $this->assertSame('Local.', $pron->transcribe($this->wav(30))['text']);
    }
}
