<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ClaudeService;
use App\Services\SpanishService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Throwable;

/** Escalera de español: ver y elegir el escalón, registrar cuando se pide español y traducir con límite. */
class SpanishController extends Controller
{
    public function __construct(private SpanishService $spanish) {}

    public function show(Request $request)
    {
        return $this->spanish->summary($request->user());
    }

    /** step = 1–4 para fijarlo a mano, o null para automático. */
    public function update(Request $request)
    {
        $data = $request->validate(['step' => ['present', 'nullable', 'integer', 'between:1,4']]);
        $request->user()->forceFill(['spanish_step' => $data['step']])->save();

        return $this->spanish->summary($request->user()->fresh());
    }

    /** El alumno pidió ver algo en español (la traducción de una ficha, una pista…). */
    public function use(Request $request)
    {
        $data = $request->validate(['kind' => ['required', Rule::in(SpanishService::KINDS)]]);
        $r = $this->spanish->use($request->user(), $data['kind']);
        abort_unless($r['allowed'], 429, $this->spanish->step($request->user()) >= 4
            ? 'Estás en el escalón "solo inglés": aquí ya no hay español. Intenta explicarlo con otras palabras.'
            : 'Ya usaste el español de hoy. Mañana tienes más.');

        return $r;
    }

    /** Traduce al español un texto corto de la app (una corrección, un comentario). Cuenta como un uso. */
    public function translate(Request $request, ClaudeService $claude)
    {
        $data = $request->validate(['text' => ['required', 'string', 'max:600']]);
        abort_unless($claude->enabled(), 503, 'La IA no está configurada en el servidor (ANTHROPIC_API_KEY).');
        $r = $this->spanish->use($request->user(), 'translate');
        abort_unless($r['allowed'], 429, 'Ya usaste el español de hoy. Mañana tienes más.');
        try {
            $text = trim($claude->message('Translate the user text into natural Latin American Spanish. Reply with the translation only.', [['role' => 'user', 'content' => $data['text']]], 400));
        } catch (Throwable $e) {
            report($e);
            abort(502, 'No se pudo traducir ahora. Intenta otra vez.');
        }

        return ['text' => $text] + $r;
    }
}
