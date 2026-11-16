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
        // Primero las escenas escritas de antemano (sin IA); si la palabra no está, se piden a la IA.
        if ($ready = self::prepared($word->word)) {
            return ['suggestions' => $ready];
        }
        abort_unless($claude->enabled(), 503, 'La IA no está configurada en el servidor (ANTHROPIC_API_KEY).');

        try {
            return ['suggestions' => $claude->suggestAid($word->word, (string) $word->translation)];
        } catch (Throwable $e) {
            report($e);
            abort(502, 'No se pudieron generar sugerencias ahora. Intenta en un momento.');
        }
    }

    /** Escenas preparadas en database/content/aids.json: {"word": ["...", "...", "..."]}. */
    public static function prepared(string $word): array
    {
        static $bank = [];
        $path = (string) config('vocab.aids_bank', database_path('content/aids.json'));
        if (! array_key_exists($path, $bank)) {
            $data = is_file($path) ? json_decode((string) file_get_contents($path), true) : null;
            $bank[$path] = is_array($data) ? array_change_key_case($data, CASE_LOWER) : [];
        }
        $list = $bank[$path][mb_strtolower($word)] ?? [];

        return array_values(array_slice(array_filter(is_array($list) ? $list : [], fn ($s) => is_string($s) && trim($s) !== ''), 0, 3));
    }
}
