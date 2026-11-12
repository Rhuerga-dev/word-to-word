<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
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
    public function transcribe(string $wavBytes, string $language = 'en-US'): array
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
