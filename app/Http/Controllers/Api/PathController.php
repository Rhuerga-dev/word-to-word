<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SpeakingSession;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\ClaudeService;
use App\Services\SrsService;
use App\Services\UnitService;
use App\Services\XpService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Throwable;

/** Camino: unidades por tema con palabras, sonido, shadowing y una prueba de conversación. */
class PathController extends Controller
{
    public function __construct(private UnitService $units, private SrsService $srs) {}

    public function index(Request $request)
    {
        return $this->units->path($request->user());
    }

    /** Palabras de la unidad que aún no aprendiste (hasta 5), como fichas nuevas. */
    public function words(Request $request, string $unit)
    {
        $user = $request->user();
        $u = $this->units->openFor($user, $unit);
        abort_unless($u, 404, 'Esa unidad no está disponible.');
        $known = UserWord::where('user_id', $user->id)->whereNotNull('introduced_at')->pluck('word_id')->flip();
        $cards = $this->units->words($this->units->find($unit))
            ->reject(fn (Word $w) => isset($known[$w->id]))->take(5)
            ->map(fn (Word $w) => StudyController::cardFor($w, null, 'new', $this->srs, app(\App\Services\SpanishService::class)->step($user)))->values();

        return ['unit' => $unit, 'cards' => $cards];
    }

    /** Shadowing de la unidad terminado (con un promedio razonable). */
    public function shadow(Request $request, string $unit)
    {
        $user = $request->user();
        abort_unless($this->units->openFor($user, $unit), 404, 'Esa unidad no está disponible.');
        $data = $request->validate(['score' => ['required', 'integer', 'min:0', 'max:100']]);
        abort_if($data['score'] < 60, 422, 'Necesitas al menos 60% de promedio para dar el shadowing por hecho.');
        $this->units->progress($user, $unit);
        DB::table('unit_progress')->where('user_id', $user->id)->where('unit', $unit)->whereNull('shadow_at')->update(['shadow_at' => now(), 'updated_at' => now()]);

        return $this->units->path($user);
    }

    /**
     * Prueba de la unidad: la conversación de su situación. La IA la califica (0–10) y explica en español.
     * Se aprueba con la nota mínima y suficientes turnos tuyos; aprobar desbloquea la siguiente unidad.
     */
    public function test(Request $request, string $unit, ClaudeService $claude, XpService $xp)
    {
        $user = $request->user();
        $u = $this->units->openFor($user, $unit);
        abort_unless($u, 404, 'Esa unidad no está disponible.');
        abort_unless($u['test_ready'], 422, 'Antes de la prueba termina los otros pasos de la unidad.');
        abort_unless($claude->enabled(), 503, 'La IA no está configurada en el servidor (ANTHROPIC_API_KEY).');
        $data = $request->validate([
            'session_id' => ['required', 'integer'],
            'messages' => ['required', 'array', 'min:2', 'max:60'],
            'messages.*.role' => ['required', 'in:user,assistant'],
            'messages.*.content' => ['required', 'string', 'max:2000'],
        ]);
        $session = SpeakingSession::where('user_id', $user->id)->find($data['session_id']);
        abort_unless($session && $session->scenario === $u['scenario'], 422, 'La prueba tiene que ser una conversación de la situación de la unidad.');

        $turns = collect($data['messages'])->where('role', 'user')->count();
        $min = (int) config('units.test_min_turns', 5);
        if ($turns < $min) {
            return ['passed' => false, 'score' => null, 'feedback' => "Habla un poco más: necesitas al menos {$min} respuestas tuyas (llevas {$turns}).", 'path' => $this->units->path($user)];
        }

        try {
            [$score, $feedback] = $claude->explainIn(app(\App\Services\SpanishService::class)->coachLang($user))->gradeConversation($data['messages'], (string) config("speaking.scenarios.{$u['scenario']}.title"), $user->cefr_level);
        } catch (Throwable $e) {
            report($e);
            abort(502, 'La IA no respondió. Intenta otra vez.');
        }
        $passed = $score >= (int) config('units.test_pass', 6);
        $row = $this->units->progress($user, $unit);
        DB::table('unit_progress')->where('id', $row->id)->update([
            'test_score' => max((int) $row->test_score, $score),
            'test_tries' => (int) $row->test_tries + 1,
            'test_feedback' => mb_substr($feedback, 0, 600),
            'passed_at' => $row->passed_at ?? ($passed ? now() : null),
            'updated_at' => now(),
        ]);
        $gained = $passed && ! $row->passed_at ? $xp->add($user, 'unit') : 0;

        return ['passed' => $passed, 'score' => $score, 'feedback' => $feedback, 'xp_gained' => $gained, 'path' => $this->units->path($user)];
    }
}
