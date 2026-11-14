<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
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
        return (bool) config('vocab.tts.enabled', true) && (filled(config('vocab.azure_speech.key')) || $this->localUp());
    }

    /** ¿Está encendida la voz local? (se recuerda 1 min para no preguntar en cada frase) */
    public function localUp(): bool
    {
        $url = config('vocab.tts.local_url');
        if (blank($url)) {
            return false;
        }

        return Cache::remember('tts:local-up', 60, function () use ($url) {
            try {
                return Http::connectTimeout(1)->timeout(2)->get(rtrim($url, '/').'/health')->successful();
            } catch (\Throwable) {
                return false;
            }
        });
    }

    /** Proveedor para esta frase: "kokoro" (local) si está encendido, si no "azure". */
    public function provider(?string $wanted = null): string
    {
        $azure = filled(config('vocab.azure_speech.key'));
        if ($wanted === 'azure' && $azure) {
            return 'azure';
        }
        if ($wanted === 'kokoro' || ! $azure) {
            return 'kokoro';
        }

        return $this->localUp() ? 'kokoro' : 'azure';
    }

    /** @return string ruta del mp3 dentro del disco "local" */
    public function audio(string $text, string $lang, bool $slow = false, ?string $provider = null): string
    {
        $lang = $lang === 'es' ? 'es' : 'en';
        if ($this->provider($provider) === 'kokoro') {
            try {
                return $this->local($text, $lang, $slow);
            } catch (\Throwable $e) {
                Cache::put('tts:local-up', false, 60);   // se apagó: un minuto con Azure
                if ($provider === 'kokoro' || blank(config('vocab.azure_speech.key'))) {
                    throw $e;
                }
            }
        }
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

        // Si Azure acaba de fallar por red o caída, no esperar otra vez: la app usa la voz del teléfono.
        if (Cache::get('tts:azure-down')) {
            throw new RuntimeException('Azure TTS caído hace poco; se reintenta en un minuto.');
        }
        $region = config('vocab.azure_speech.region');
        try {
            $response = Http::connectTimeout(3)->timeout(8)->withHeaders([
                'Ocp-Apim-Subscription-Key' => config('vocab.azure_speech.key'),
                'X-Microsoft-OutputFormat' => 'audio-24khz-48kbitrate-mono-mp3',
                'User-Agent' => 'word-to-word',
            ])->withBody($ssml, 'application/ssml+xml')
                ->post("https://{$region}.tts.speech.microsoft.com/cognitiveservices/v1");
        } catch (ConnectionException $e) {
            Cache::put('tts:azure-down', true, 60);   // sin red o sin respuesta: un minuto sin preguntar
            throw $e;
        }

        if (! $response->successful() || $response->body() === '') {
            if ($response->serverError()) {
                Cache::put('tts:azure-down', true, 60);
            }
            throw new RuntimeException('Azure TTS respondió '.$response->status());
        }

        Storage::disk('local')->put($path, $response->body());
        AiUsage::tts($text);   // solo cuando Azure genera audio nuevo (lo cacheado y Kokoro no cuestan)

        return $path;
    }

    /** Voz local Kokoro (tts-local/server.py en este Mac). */
    private function local(string $text, string $lang, bool $slow): string
    {
        $path = 'tts/'.hash('sha256', 'kokoro|'.$lang.'|'.($slow ? 1 : 0).'|'.$text).'.mp3';
        if (Storage::disk('local')->exists($path)) {
            @touch(Storage::disk('local')->path($path));

            return $path;
        }
        $res = Http::connectTimeout(1)->timeout(20)->post(rtrim(config('vocab.tts.local_url'), '/').'/tts', compact('text', 'lang', 'slow'));
        if (! $res->successful() || $res->body() === '') {
            throw new RuntimeException('La voz local respondió '.$res->status());
        }
        Storage::disk('local')->put($path, $res->body());

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
