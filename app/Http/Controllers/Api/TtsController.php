<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\TtsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Throwable;

class TtsController extends Controller
{
    /** Audio mp3 con voz natural. La app usa la voz del navegador si esto falla. */
    public function show(Request $request, TtsService $tts)
    {
        $data = $request->validate([
            'text' => ['required', 'string', 'max:400'],
            'lang' => ['required', 'in:en,es'],
            'slow' => ['nullable', 'boolean'],
            'provider' => ['nullable', 'in:azure,kokoro'],   // para comparar voces en Ajustes
        ]);
        abort_unless($tts->enabled(), 503, 'Voces naturales no configuradas.');

        try {
            $path = $tts->audio(trim($data['text']), $data['lang'], (bool) ($data['slow'] ?? false), $data['provider'] ?? null);
        } catch (Throwable $e) {
            report($e);
            abort(502, 'No se pudo generar la voz ahora.');
        }

        return response()->file(Storage::disk('local')->path($path), [
            'Content-Type' => 'audio/mpeg',
            'Cache-Control' => 'private, max-age=2592000',
        ]);
    }
}
