<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Throwable;
use RuntimeException;

/**
 * Evaluación de pronunciación con Azure AI Speech (Pronunciation Assessment).
 * Recibe audio WAV PCM 16 kHz mono y el texto esperado; devuelve puntajes
 * generales, por palabra y por sonido (fonema IPA).
 */
class PronunciationService
{
    public function enabled(): bool
    {
        return filled(config('vocab.azure_speech.key'));
    }

    public function assess(string $wavBytes, string $referenceText): array
    {
        if (! $this->enabled()) {
            throw new RuntimeException('Falta AZURE_SPEECH_KEY en el archivo .env');
        }

        $config = base64_encode(json_encode([
            'ReferenceText' => $referenceText,
            'GradingSystem' => 'HundredMark',
            'Granularity' => 'Phoneme',
            'Dimension' => 'Comprehensive',
            'EnableMiscue' => true,
            'PhonemeAlphabet' => 'IPA',
        ]));

        $region = config('vocab.azure_speech.region');
        $url = "https://{$region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1"
            .'?language=en-US&format=detailed';

        $response = Http::withHeaders([
            'Ocp-Apim-Subscription-Key' => config('vocab.azure_speech.key'),
            'Pronunciation-Assessment' => $config,
            'Accept' => 'application/json',
        ])
            ->withBody($wavBytes, 'audio/wav; codecs=audio/pcm; samplerate=16000')
            ->timeout(30)
            ->post($url);

        if ($response->failed()) {
            throw new RuntimeException('Error de Azure Speech: '.$response->status());
        }
        AiUsage::speech('assess', $wavBytes);

        $json = $response->json();
        if (($json['RecognitionStatus'] ?? '') !== 'Success' || empty($json['NBest'][0])) {
            return [
                'recognized' => '',
                'scores' => ['pron' => 0, 'accuracy' => 0, 'fluency' => 0, 'completeness' => 0],
                'words' => [],
                'status' => $json['RecognitionStatus'] ?? 'Unknown',
            ];
        }

        $best = $json['NBest'][0];
        // Azure devuelve los puntajes dentro de PronunciationAssessment (formato nuevo) o directo (formato viejo).
        $pa = $best['PronunciationAssessment'] ?? $best;

        $words = collect($best['Words'] ?? [])->map(function ($w) {
            $wa = $w['PronunciationAssessment'] ?? $w;

            return [
                'word' => $w['Word'] ?? '',
                'accuracy' => (int) round($wa['AccuracyScore'] ?? 0),
                'error' => $wa['ErrorType'] ?? 'None',           // None | Mispronunciation | Omission | Insertion
                'phonemes' => collect($w['Phonemes'] ?? [])->map(fn ($p) => [
                    'phoneme' => $p['Phoneme'] ?? '',
                    'accuracy' => (int) round(($p['PronunciationAssessment'] ?? $p)['AccuracyScore'] ?? 0),
                ])->values()->all(),
            ];
        })->values()->all();

        return [
            'recognized' => $best['Display'] ?? ($best['Lexical'] ?? ''),
            'scores' => [
                'pron' => (int) round($pa['PronScore'] ?? 0),
                'accuracy' => (int) round($pa['AccuracyScore'] ?? 0),
                'fluency' => (int) round($pa['FluencyScore'] ?? 0),
                'completeness' => (int) round($pa['CompletenessScore'] ?? 0),
            ],
            'words' => $words,
            'status' => 'Success',
        ];
    }

    /**
     * Lo que dijo el alumno en una conversación (sin texto esperado), con el momento de cada palabra
     * para medir la fluidez: palabras por minuto y pausas largas.
     *
     * @return array{text: string, words: int, speech_ms: int, long_pauses: int, wpm: int|null}
     */
    /** Desde aquí, el audio largo (narración) va a Whisper aunque no se pida: ahí no se califica palabra por palabra. */
    public const LOCAL_FROM_SECS = 12;

    /**
     * Voz a texto. [$freeSpeech] = habla libre (conversación): se usa Whisper en este Mac (gratis).
     * Lo corto que se califica (repetir, órdenes, errores) sigue en Azure, que no "arregla" lo que dices.
     * Si Whisper no está o falla, Azure como siempre.
     */
    public function transcribe(string $wavBytes, string $language = 'en-US', bool $freeSpeech = false): array
    {
        $secs = max(0, (strlen($wavBytes) - 44) / 32000);
        if (($freeSpeech || $secs >= self::LOCAL_FROM_SECS) && $this->whisperUp()) {
            try {
                return $this->whisper($wavBytes, $language);
            } catch (Throwable $e) {
                Cache::put('whisper:up', false, 60);   // apagado o colgado: un minuto con Azure
                report($e);
            }
        }

        return $this->azureTranscribe($wavBytes, $language);
    }

    /** ¿Hay Whisper local configurado y no falló hace poco? (WHISPER_URL en el .env). */
    public function whisperUp(): bool
    {
        return filled(config('vocab.whisper.url')) && Cache::get('whisper:up', true) !== false;
    }

    /**
     * Voz a texto con whisper-server (whisper.cpp, modelo large-v3-turbo en memoria).
     * audio_ctx: para frases cortas solo se mira la parte con audio (la mitad de tiempo); 1500 = 30 s.
     */
    public function whisper(string $wavBytes, string $language = 'en-US'): array
    {
        $secs = max(0, (strlen($wavBytes) - 44) / 32000);
        $fields = ['response_format' => 'verbose_json', 'language' => str_starts_with($language, 'es') ? 'es' : 'en', 'temperature' => '0'];
        if ($secs < 29) {
            $fields['audio_ctx'] = (string) min(1500, max(512, (int) (ceil(($secs + 1.5) * 50 / 64) * 64)));
        }

        $json = Http::timeout($secs > 20 ? 90 : 20)->connectTimeout(1)
            ->attach('file', $wavBytes, 'audio.wav')
            ->post(rtrim(config('vocab.whisper.url'), '/').'/inference', $fields)
            ->throw()->json();
        if (! is_array($json) || ! array_key_exists('text', $json)) {
            throw new RuntimeException('Respuesta rara de Whisper');
        }
        AiUsage::local('whisper', 'transcribe', $wavBytes);

        // Whisper se inventa frases con silencio o ruido ("Thank you for watching"): esos trozos se descartan.
        $segments = collect($json['segments'] ?? [])->reject(fn ($s) => ($s['no_speech_prob'] ?? 0) > 0.6 && ($s['avg_logprob'] ?? 0) < -0.8);
        $text = isset($json['segments']) ? $segments->pluck('text')->implode(' ') : (string) $json['text'];
        $text = trim(preg_replace('/\s+/', ' ', $text));
        if (preg_match('/^\[?(blank_audio|music|silence|inaudible)\]?$/i', $text)) {
            $text = '';
        }

        $timeline = $segments->flatMap(fn ($s) => $s['words'] ?? [])
            ->filter(fn ($w) => preg_match('/[A-Za-z0-9]/', $w['word'] ?? ''))
            ->map(fn ($w) => ['start' => (int) round(($w['start'] ?? 0) * 1000), 'end' => (int) round(($w['end'] ?? 0) * 1000)])
            ->values()->all();

        return ['text' => $text] + self::fluency($timeline);
    }

    /** Voz a texto con Azure (de pago). */
    public function azureTranscribe(string $wavBytes, string $language = 'en-US'): array
    {
        if (! $this->enabled()) {
            throw new RuntimeException('Falta AZURE_SPEECH_KEY en el archivo .env');
        }

        $region = config('vocab.azure_speech.region');
        $url = "https://{$region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1"
            .'?language='.$language.'&format=detailed&wordLevelTimestamps=true&profanity=raw';

        $response = Http::withHeaders([
            'Ocp-Apim-Subscription-Key' => config('vocab.azure_speech.key'),
            'Accept' => 'application/json',
        ])
            ->withBody($wavBytes, 'audio/wav; codecs=audio/pcm; samplerate=16000')
            ->timeout(30)
            ->post($url);

        if ($response->failed()) {
            throw new RuntimeException('Error de Azure Speech: '.$response->status());
        }
        AiUsage::speech('transcribe', $wavBytes);

        $json = $response->json();
        $best = $json['NBest'][0] ?? null;
        if (($json['RecognitionStatus'] ?? '') !== 'Success' || ! $best) {
            return ['text' => ''] + self::fluency([]);
        }

        // Azure da el inicio y la duración de cada palabra en unidades de 100 ns.
        $timeline = collect($best['Words'] ?? [])->map(fn ($w) => [
            'start' => (int) round(($w['Offset'] ?? 0) / 10000),
            'end' => (int) round((($w['Offset'] ?? 0) + ($w['Duration'] ?? 0)) / 10000),
        ])->values()->all();

        return ['text' => trim($best['Display'] ?? ($best['Lexical'] ?? ''))] + self::fluency($timeline);
    }

    /**
     * Ritmo de una frase a partir de cuándo empieza y termina cada palabra (ms).
     *
     * @param  array<int, array{start: int, end: int}>  $timeline
     * @return array{words: int, speech_ms: int, long_pauses: int, wpm: int|null}
     */
    public static function fluency(array $timeline): array
    {
        $n = count($timeline);
        if ($n === 0) {
            return ['words' => 0, 'speech_ms' => 0, 'long_pauses' => 0, 'wpm' => null];
        }
        $limit = (int) config('speaking.long_pause_ms', 700);
        $pauses = 0;
        for ($i = 1; $i < $n; $i++) {
            if ($timeline[$i]['start'] - $timeline[$i - 1]['end'] >= $limit) {
                $pauses++;
            }
        }
        $ms = max(0, $timeline[$n - 1]['end'] - $timeline[0]['start']);

        return [
            'words' => $n,
            'speech_ms' => $ms,
            'long_pauses' => $pauses,
            // Con menos de 3 palabras el ritmo no dice nada.
            'wpm' => $n >= 3 && $ms > 0 ? (int) round($n / ($ms / 60000)) : null,
        ];
    }
}
