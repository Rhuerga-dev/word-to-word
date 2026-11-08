<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

/**
 * Voces naturales (neuronales) de Azure para leer palabras, frases y consejos.
 * Cada audio se guarda en storage/app/tts: la misma frase no se vuelve a pedir
 * (y no gasta del límite gratis de Azure).
 */
class TtsService
{
    /** Voz por idioma. Se pueden cambiar en el .env. */
    public function voices(): array
    {
        return [
            'en' => config('vocab.tts.voice_en', 'en-US-AvaMultilingualNeural'),
            'es' => config('vocab.tts.voice_es', 'es-MX-DaliaNeural'),
        ];
    }

    public function enabled(): bool
    {
        return (bool) config('vocab.tts.enabled', true) && filled(config('vocab.azure_speech.key'));
    }

    /** @return string ruta del mp3 dentro del disco "local" */
    public function audio(string $text, string $lang, bool $slow = false): string
    {
        $lang = $lang === 'es' ? 'es' : 'en';
        $voice = $this->voices()[$lang];
        // Lento: inglés -30%; español -20% con pausas en comas y puntos (para las escenas AID).
        $rate = $slow ? ($lang === 'en' ? '-30%' : '-20%') : ($lang === 'en' ? '-5%' : '0%');
        $path = 'tts/'.hash('sha256', $voice.'|'.$rate.'|'.$text).'.mp3';

        if (Storage::disk('local')->exists($path)) {
            @touch(Storage::disk('local')->path($path));   // usado hoy: tts:prune no lo borra por viejo

            return $path;
        }

        $xmlLang = $lang === 'es' ? 'es-MX' : 'en-US';
        $ssml = '<speak version="1.0" xml:lang="'.$xmlLang.'"><voice name="'.$voice.'">'
            .'<prosody rate="'.$rate.'">'.$this->body($text, $slow).'</prosody></voice></speak>';

        $region = config('vocab.azure_speech.region');
        $response = Http::timeout(15)->withHeaders([
            'Ocp-Apim-Subscription-Key' => config('vocab.azure_speech.key'),
            'X-Microsoft-OutputFormat' => 'audio-24khz-48kbitrate-mono-mp3',
            'User-Agent' => 'word-to-word',
        ])->withBody($ssml, 'application/ssml+xml')
            ->post("https://{$region}.tts.speech.microsoft.com/cognitiveservices/v1");

        if (! $response->successful() || $response->body() === '') {
            throw new RuntimeException('Azure TTS respondió '.$response->status());
        }

        Storage::disk('local')->put($path, $response->body());

        return $path;
    }

    /** Texto escapado; en modo lento agrega pausas después de comas, dos puntos y puntos. */
    private function body(string $text, bool $slow): string
    {
        $safe = htmlspecialchars($text, ENT_XML1 | ENT_QUOTES, 'UTF-8');
        if (! $slow) {
            return $safe;
        }

        return preg_replace(
            ['/([,;:])\s+/u', '/([.!?¡¿])\s+/u'],
            ['$1<break time="350ms"/> ', '$1<break time="650ms"/> '],
            $safe
        );
    }
}
