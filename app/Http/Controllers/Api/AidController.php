<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\ClaudeService;
use Illuminate\Http\Request;
use Throwable;

/** Escenas AID (Acción Irracional Detallada) por palabra. */
class AidController extends Controller
{
    public function update(Request $request, Word $word)
    {
        $data = $request->validate(['aid' => ['nullable', 'string', 'max:1000']]);

        $uw = UserWord::firstOrNew(['user_id' => $request->user()->id, 'word_id' => $word->id]);
        $uw->aid = $data['aid'] ?? null;
        $uw->save();

        return ['aid' => $uw->aid];
    }

    public function suggest(Word $word, ClaudeService $claude)
    {
        abort_unless($claude->enabled(), 503, 'La IA no está configurada en el servidor (ANTHROPIC_API_KEY).');

        try {
            return ['suggestions' => $claude->suggestAid($word->word, (string) $word->translation)];
        } catch (Throwable $e) {
            report($e);
            abort(502, 'No se pudieron generar sugerencias ahora. Intenta en un momento.');
        }
    }
}
