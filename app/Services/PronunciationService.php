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
}
