<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SpeakingMistake;
use App\Models\SpeakingSession;
use App\Services\ClaudeService;
use App\Services\PictureService;
use App\Services\PronunciationService;
use App\Services\SpeakingService;
use App\Services\SrsService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Throwable;

/** Conversación por voz: situaciones, turnos con medición de fluidez, resumen, errores y metas. */
class SpeakingController extends Controller
{
    public function __construct(private SpeakingService $speaking, private SrsService $srs) {}

    public function scenarios()
    {
        return ['scenarios' => collect(config('speaking.scenarios'))
            ->map(fn ($s, $id) => ['id' => $id, 'title' => $s['title'], 'emoji' => $s['emoji'], 'desc' => $s['desc']])
            ->values()];
    }

    public function stats(Request $request)
    {
        return $this->speaking->stats($request->user());
    }

    public function start(Request $request)
    {
        $data = $request->validate([
            'scenario' => ['required', 'string', Rule::in([...array_keys(config('speaking.scenarios')), 'narrate', 'picture'])],
            'skip' => ['sometimes', 'integer', 'min:0', 'max:100'],   // narración: otro tema
        ]);
        $user = $request->user();
        $topic = $data['scenario'] === 'narrate' ? $this->speaking->topic($user, (int) ($data['skip'] ?? 0)) : null;
        $session = SpeakingSession::create([
            'user_id' => $user->id,
            'scenario' => $data['scenario'],
            'day' => $this->srs->today($user)->toDateString(),
            'topic' => $topic['en'] ?? null,
        ]);

        $seconds = $data['scenario'] === 'picture' ? config('speaking.picture_seconds') : config('speaking.narration_seconds');

        return response()->json(['id' => $session->id, 'scenario' => $session->scenario, 'topic' => $topic, 'seconds' => $seconds], 201);
    }

    /**
     * Lo que dijiste en un turno. Con Azure se manda el audio y el servidor lo transcribe y mide el ritmo.
     * Sin Azure (navegador), se manda el texto reconocido y cuánto duró: se estima el ritmo.
     */
    public function turn(Request $request, PronunciationService $pron, SpeakingSession $session)
    {
        abort_unless($session->user_id === $request->user()->id, 404);
        abort_if($session->ended_at !== null, 409, 'Esta conversación ya terminó. Empieza otra.');

        // Cuánto tardó en empezar a hablar desde que terminó la pregunta (lo mide la app).
        $reaction = $request->validate(['reaction_ms' => ['sometimes', 'nullable', 'integer', 'min:0', 'max:60000']])['reaction_ms'] ?? null;

        if ($request->hasFile('audio')) {
            abort_unless($pron->enabled(), 503, 'La transcripción de voz no está configurada en el servidor (AZURE_SPEECH_KEY).');
            $request->validate(['audio' => ['required', 'file', 'max:4096']]);   // ~60 s de WAV 16 kHz mono
            try {
                $out = $pron->transcribe($request->file('audio')->get());
            } catch (Throwable $e) {
                report($e);
                abort(502, 'No se pudo entender el audio ahora. Intenta otra vez.');
            }
        } else {
            $data = $request->validate([
                'text' => ['required', 'string', 'max:1000'],
                'ms' => ['required', 'integer', 'min:0', 'max:60000'],
            ]);
            $n = str_word_count($data['text']);
            // El navegador no da el momento de cada palabra: se cuenta el tiempo total y no se miden pausas.
            $out = ['text' => trim($data['text']), 'words' => $n, 'speech_ms' => $data['ms'], 'long_pauses' => 0,
                'wpm' => $n >= 3 && $data['ms'] > 0 ? (int) round($n / ($data['ms'] / 60000)) : null];
        }

        if ($out['words'] > 0) {
            $this->speaking->addTurn($session, $out, $reaction !== null ? (int) $reaction : null);
        }

        return $out + ['today' => $this->speaking->stats($request->user())['today']];
    }

    /** Correcciones de la narración de un minuto: comentario, versión más natural y errores para repasar. */
    public function narration(Request $request, ClaudeService $claude, SpeakingSession $session)
    {
        abort_unless($session->user_id === $request->user()->id, 404);
        abort_unless($session->scenario === 'narrate', 422, 'Esta sesión no es una narración.');
        abort_unless($claude->enabled(), 503, 'La IA no está configurada en el servidor (ANTHROPIC_API_KEY).');
        $data = $request->validate(['text' => ['required', 'string', 'min:3', 'max:4000']]);
        $user = $request->user();

        try {
            $out = $claude->narration($session->topic ?? 'free topic', $data['text'], $user->cefr_level);
        } catch (Throwable $e) {
            report($e);
            abort(502, 'La IA no respondió. Intenta otra vez.');
        }
        $mistakes = $this->speaking->saveMistakes($user, $out['mistakes'], $session, $this->srs->today($user));

        return ['comment' => $out['reply'], 'better' => $out['better'], 'feedback' => $out['feedback'], 'mistakes' => $mistakes];
    }

    /** Una foto para describir (Unsplash). */
    public function picture(PictureService $pictures)
    {
        abort_unless($pictures->enabled(), 503, 'Las fotos no están configuradas en el servidor (UNSPLASH_ACCESS_KEY).');
        try {
            $p = $pictures->random();
        } catch (Throwable $e) {
            report($e);
            abort(502, 'No se pudo traer una foto ahora. Intenta otra vez.');
        }
        abort_unless(PictureService::allowed($p['url']), 502, 'La foto no es válida.');

        return $p;
    }

    /** La IA mira la misma foto y corrige tu descripción: palabras que te faltaron, versión natural y errores. */
    public function describe(Request $request, ClaudeService $claude, SpeakingSession $session)
    {
        abort_unless($session->user_id === $request->user()->id, 404);
        abort_unless($session->scenario === 'picture', 422, 'Esta sesión no es de describir una foto.');
        abort_unless($claude->enabled(), 503, 'La IA no está configurada en el servidor (ANTHROPIC_API_KEY).');
        $data = $request->validate([
            'text' => ['required', 'string', 'min:3', 'max:4000'],
            'image_url' => ['required', 'string', 'max:1000'],
        ]);
        abort_unless(PictureService::allowed($data['image_url']), 422, 'Solo se pueden describir fotos de Unsplash.');
        $user = $request->user();
        $session->update(['topic' => mb_substr('photo: '.$data['image_url'], 0, 200)]);

        try {
            $out = $claude->describePicture($data['image_url'], $data['text'], $user->cefr_level);
        } catch (Throwable $e) {
            report($e);
            abort(502, 'La IA no respondió. Intenta otra vez.');
        }
        $mistakes = $this->speaking->saveMistakes($user, $out['mistakes'], $session, $this->srs->today($user));

        return ['comment' => $out['reply'], 'better' => $out['better'], 'missed' => $out['missed'], 'feedback' => $out['feedback'], 'mistakes' => $mistakes];
    }

    public function finish(Request $request, SpeakingSession $session)
    {
        abort_unless($session->user_id === $request->user()->id, 404);
        if (! $session->ended_at) {
            $session->update(['ended_at' => now()]);
        }

        return $this->speaking->summary($session) + ['stats' => $this->speaking->stats($request->user())];
    }

    /** Errores que tocan repasar hoy. */
    public function mistakes(Request $request)
    {
        $user = $request->user();
        $today = $this->srs->today($user)->toDateString();

        return ['mistakes' => SpeakingMistake::where('user_id', $user->id)->whereNull('mastered_on')
            ->whereDate('next_review', '<=', $today)->orderBy('next_review')->orderBy('id')->limit(20)->get()
            ->map->toCard()->values()];
    }

    /**
     * Repaso de un error: dices la frase correcta en voz alta y el servidor comprueba las palabras.
     * Con Azure se manda el audio; sin Azure, el texto que reconoció el navegador.
     */
    public function review(Request $request, PronunciationService $pron, SpeakingMistake $mistake)
    {
        abort_unless($mistake->user_id === $request->user()->id, 404);

        if ($request->hasFile('audio')) {
            abort_unless($pron->enabled(), 503, 'La transcripción de voz no está configurada en el servidor (AZURE_SPEECH_KEY).');
            $request->validate(['audio' => ['required', 'file', 'max:2048']]);
            try {
                $heard = $pron->transcribe($request->file('audio')->get())['text'];
            } catch (Throwable $e) {
                report($e);
                abort(502, 'No se pudo entender el audio ahora. Intenta otra vez.');
            }
        } else {
            $heard = $request->validate(['text' => ['required', 'string', 'max:1000']])['text'];
        }

        $match = self::match($mistake->correct, (string) $heard);
        if ($heard === '' || $match['pct'] === 0) {
            // No se oyó nada: no cuenta como fallo.
            return ['heard' => $heard, 'pct' => 0, 'tokens' => $match['tokens'], 'silent' => true] + $mistake->toCard();
        }

        return ['heard' => $heard, 'pct' => $match['pct'], 'tokens' => $match['tokens'], 'passed' => $match['pct'] >= self::PASS]
            + $this->speaking->review($mistake, $match['pct'] >= self::PASS, $this->srs->today($request->user()));
    }

    /** % de palabras de la frase correcta que se dijeron (para aprobar un repaso). */
    public const PASS = 85;

    public static function match(string $target, string $heard): array
    {
        $norm = fn (string $t) => array_values(array_filter(preg_split('/\s+/', preg_replace('/[^a-z0-9\s]/', ' ', str_replace(["'", '’'], '', mb_strtolower($t))))));
        $pool = $norm($heard);
        $tokens = [];
        foreach ($norm($target) as $w) {
            $i = array_search($w, $pool, true);
            if ($i !== false) {
                unset($pool[$i]);
            }
            $tokens[] = ['w' => $w, 'ok' => $i !== false];
        }
        $ok = count(array_filter($tokens, fn ($t) => $t['ok']));

        return ['pct' => $tokens ? (int) round($ok / count($tokens) * 100) : 0, 'tokens' => $tokens];
    }

    public function goal(Request $request)
    {
        $data = $request->validate(['speaking_goal' => ['required', 'integer', 'min:1', 'max:60']]);
        $request->user()->forceFill($data)->save();

        return $this->speaking->stats($request->user());
    }
}
