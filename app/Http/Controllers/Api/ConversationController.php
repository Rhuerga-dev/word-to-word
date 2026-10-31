<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserWord;
use App\Services\ClaudeService;
use App\Services\SrsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Throwable;

/** Conversación con IA que te hace usar las palabras de hoy. */
class ConversationController extends Controller
{
    public function store(Request $request, ClaudeService $claude, SrsService $srs)
    {
        abort_unless($claude->enabled(), 503, 'La IA no está configurada en el servidor (ANTHROPIC_API_KEY).');

        $data = $request->validate([
            'messages' => ['present', 'array', 'max:40'],
            'messages.*.role' => ['required', 'in:user,assistant'],
            'messages.*.content' => ['required', 'string', 'max:2000'],
        ]);

        $user = $request->user();
        $today = $srs->today($user);

        // Palabras de hoy: las nuevas de hoy + las repasadas hoy; si no hay, las más recientes.
        $targets = UserWord::with('word')
            ->where('user_id', $user->id)
            ->whereNotNull('introduced_at')
            ->where(fn ($q) => $q->whereDate('introduced_at', $today)->orWhereDate('updated_at', today()))
            ->limit(15)->get()->pluck('word.word');
        if ($targets->isEmpty()) {
            $targets = UserWord::with('word')->where('user_id', $user->id)
                ->whereNotNull('introduced_at')->latest('introduced_at')->limit(10)->get()->pluck('word.word');
        }

        $weak = DB::table('phoneme_errors')->where('user_id', $user->id)
            ->orderByDesc('count')->limit(3)->pluck('phoneme')->implode(', ');

        try {
            $out = $claude->converse($data['messages'], $targets->all(), $weak ?: null);
        } catch (Throwable $e) {
            report($e);
            abort(502, 'La IA no respondió. Intenta otra vez.');
        }

        return $out + ['targets' => $targets->values()];
    }
}
