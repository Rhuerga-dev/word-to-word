<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Suggestion;
use App\Services\DemoService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Sugerencias de los alumnos. Siempre a nombre del usuario que ha entrado (el del token). */
class SuggestionController extends Controller
{
    public function store(Request $request)
    {
        $user = $request->user();
        if (DemoService::isDemo($user)) {
            return response()->json(['message' => 'En la demo no se pueden enviar sugerencias. Crea tu cuenta para enviarlas.', 'demo' => true], 403);
        }

        // Espacios al principio y al final no cuentan para el mínimo de 5 letras.
        $request->merge(['message' => is_string($request->input('message')) ? trim($request->input('message')) : $request->input('message')]);
        $data = $request->validate([
            'type' => ['required', 'string', Rule::in(Suggestion::TYPES)],
            'message' => ['required', 'string', 'min:5', 'max:2000'],
            'app_version' => ['nullable', 'string', 'max:30', 'regex:/^[A-Za-z0-9.+_\- ]+$/'],
            'platform' => ['nullable', 'string', Rule::in(Suggestion::PLATFORMS)],
            'screen' => ['nullable', 'string', 'max:60', 'regex:/^[A-Za-z0-9._\/\- ]+$/'],
        ]);

        $since = now()->subDay();
        if (Suggestion::where('user_id', $user->id)->where('created_at', '>=', $since)->count() >= Suggestion::DAILY_PER_USER) {
            return response()->json(['message' => 'Ya enviaste muchas sugerencias hoy. Mañana puedes enviar más.'], 429);
        }
        if (Suggestion::where('created_at', '>=', $since)->count() >= Suggestion::DAILY_GLOBAL) {
            return response()->json(['message' => 'Hoy ya recibimos muchas sugerencias. Inténtalo mañana.'], 429);
        }

        $suggestion = new Suggestion($data);
        $suggestion->user_id = $user->id;      // del token, nunca del cliente
        $suggestion->status = 'new';
        $suggestion->save();

        return response()->json(['ok' => true, 'message' => '¡Gracias! Recibimos tu sugerencia.'], 201);
    }
}
