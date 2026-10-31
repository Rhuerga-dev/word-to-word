<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\PronunciationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Throwable;

class PronunciationController extends Controller
{
    /**
     * Dos formas de uso:
     *  - con archivo "audio" (WAV 16 kHz): se califica en el servidor con Azure.
     *  - con "score" (0-100): el navegador ya calificó (modo sin Azure) y solo se guarda.
     * "target" = word | sentence
     */
    public function store(Request $request, Word $word, PronunciationService $pron)
    {
        $data = $request->validate([
            'target' => ['required', 'in:word,sentence'],
            'audio' => ['nullable', 'file', 'max:2048'],
            'score' => ['nullable', 'integer', 'min:0', 'max:100'],
        ]);

        $reference = $data['target'] === 'word'
            ? $word->word
            : str_replace('*', '', (string) $word->example);

        if ($request->hasFile('audio')) {
            abort_unless($pron->enabled(), 503, 'La evaluación de pronunciación no está configurada (AZURE_SPEECH_KEY).');
            try {
                $result = $pron->assess($request->file('audio')->get(), $reference);
            } catch (Throwable $e) {
                report($e);
                abort(502, 'No se pudo evaluar el audio ahora. Intenta otra vez.');
            }
            $score = $result['scores']['pron'];
            $this->logWeakSounds($request->user()->id, $result['words']);
        } else {
            abort_if(! isset($data['score']), 422, 'Envía "audio" o "score".');
            $score = (int) $data['score'];
            $result = null;
        }

        if ($data['target'] === 'word') {
            $uw = UserWord::firstOrNew(['user_id' => $request->user()->id, 'word_id' => $word->id]);
            $uw->last_pron_score = $score;
            $uw->best_pron_score = max((int) $uw->best_pron_score, $score);
            $uw->save();
        }

        return ['reference' => $reference, 'score' => $score, 'assessment' => $result];
    }

    /** Guarda los sonidos con puntaje bajo para ver cuáles te cuestan. */
    private function logWeakSounds(int $userId, array $words): void
    {
        foreach ($words as $w) {
            foreach ($w['phonemes'] as $p) {
                if ($p['phoneme'] === '' || $p['accuracy'] >= 60) {
                    continue;
                }
                DB::table('phoneme_errors')->updateOrInsert(
                    ['user_id' => $userId, 'phoneme' => $p['phoneme']],
                    ['last_word' => $w['word'], 'updated_at' => now(), 'created_at' => now()]
                );
                DB::table('phoneme_errors')
                    ->where(['user_id' => $userId, 'phoneme' => $p['phoneme']])
                    ->increment('count');
            }
        }
    }
}
