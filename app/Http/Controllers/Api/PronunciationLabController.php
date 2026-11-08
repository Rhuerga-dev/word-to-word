<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PronunciationService;
use App\Services\SrsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Taller de pronunciación: los sonidos que más te cuestan, ejercicios evaluados
 * sonido por sonido y repetición espaciada (mañana, en 3, 7 y 14 días) hasta dominarlos.
 */
class PronunciationLabController extends Controller
{
    /** Días hasta el próximo taller según los talleres aprobados seguidos. */
    public const SPACING = [1, 3, 7, 14];

    /** Talleres aprobados (en días distintos) para darlo por dominado. */
    public const MASTER_STAGE = 4;

    public function __construct(private SrsService $srs) {}

    public function index(Request $request)
    {
        $today = $this->srs->today($request->user())->toDateString();

        $sounds = DB::table('phoneme_errors')->where('user_id', $request->user()->id)->get()
            ->map(function ($s) use ($today) {
                $next = $s->next_practice ? substr($s->next_practice, 0, 10) : null;

                return [
                    'phoneme' => $s->phoneme,
                    'errors' => (int) $s->count,
                    'last_word' => $s->last_word,
                    'stage' => (int) $s->stage,
                    'best_score' => $s->best_score,
                    'sessions' => (int) $s->sessions,
                    'next_practice' => $next,
                    'mastered' => (bool) $s->mastered_on,
                    'due' => ! $next || $next <= $today,
                ];
            })
            // Primero lo que toca hoy y te cuesta más; lo dominado al final.
            ->sortBy(fn ($s) => [$s['mastered'] ? 1 : 0, $s['due'] ? 0 : 1, -$s['errors']])
            ->values();

        return ['today' => $today, 'master_stage' => self::MASTER_STAGE, 'sounds' => $sounds];
    }

    /**
     * Evalúa un ejercicio (palabra o frase libre) y devuelve también el puntaje
     * del sonido que se está practicando. No suma errores al historial.
     */
    public function assess(Request $request, PronunciationService $pron)
    {
        $data = $request->validate([
            'text' => ['required', 'string', 'max:160', "regex:/^[A-Za-z][A-Za-z'’,.!?\\- ]*$/u"],
            'phoneme' => ['nullable', 'string', 'max:8'],
            'audio' => ['required', 'file', 'max:3072'],
        ]);
        abort_unless($pron->enabled(), 503, 'La evaluación de pronunciación no está configurada (AZURE_SPEECH_KEY).');

        try {
            $result = $pron->assess($request->file('audio')->get(), trim($data['text']));
        } catch (Throwable $e) {
            report($e);
            abort(502, 'No se pudo evaluar el audio ahora. Intenta otra vez.');
        }

        return [
            'score' => $result['scores']['pron'],
            'target_score' => self::targetScore($result['words'], $data['phoneme'] ?? null),
            'assessment' => $result,
        ];
    }

    /** Guarda cómo te fue en el taller de un sonido y programa el próximo. */
    public function result(Request $request)
    {
        $data = $request->validate([
            'phoneme' => ['required', 'string', 'max:16'],
            'passed' => ['required', 'boolean'],
            'score' => ['nullable', 'integer', 'min:0', 'max:100'],
        ]);
        $user = $request->user();
        $today = $this->srs->today($user);
        $where = ['user_id' => $user->id, 'phoneme' => $data['phoneme']];

        $row = DB::table('phoneme_errors')->where($where)->first();
        $stage = (int) ($row->stage ?? 0);
        $alreadyToday = $row && $row->practiced_on && substr($row->practiced_on, 0, 10) === $today->toDateString();

        if ($data['passed']) {
            // Aprobar dos veces el mismo día no adelanta: la memoria se fija con días de por medio.
            $stage = $alreadyToday && $stage > 0 ? $stage : min($stage + 1, self::MASTER_STAGE);
            $days = self::SPACING[min($stage, count(self::SPACING)) - 1];
        } else {
            $stage = max(0, $stage - 1);
            $days = 1;
        }

        $values = [
            'stage' => $stage,
            'sessions' => (int) ($row->sessions ?? 0) + 1,
            'best_score' => max((int) ($row->best_score ?? 0), (int) ($data['score'] ?? 0)) ?: null,
            'practiced_on' => $today->toDateString(),
            'next_practice' => $today->addDays($days)->toDateString(),
            'mastered_on' => $stage >= self::MASTER_STAGE ? ($row->mastered_on ?? $today->toDateString()) : null,
            'updated_at' => now(),
        ];
        if ($row) {
            DB::table('phoneme_errors')->where($where)->update($values);
        } else {
            DB::table('phoneme_errors')->insert($where + $values + ['count' => 0, 'created_at' => now()]);
        }

        return [
            'phoneme' => $data['phoneme'],
            'stage' => $stage,
            'mastered' => $stage >= self::MASTER_STAGE,
            'next_practice' => $values['next_practice'],
            'days' => $days,
        ];
    }

    /** Promedio de precisión del sonido practicado en lo que dijiste (null si no aparece). */
    public static function targetScore(array $words, ?string $phoneme): ?int
    {
        if (! $phoneme) {
            return null;
        }
        $target = self::norm($phoneme);
        $hits = [];
        foreach ($words as $w) {
            foreach ($w['phonemes'] ?? [] as $p) {
                if (self::norm($p['phoneme']) === $target) {
                    $hits[] = $p['accuracy'];
                }
            }
        }

        return $hits ? (int) round(array_sum($hits) / count($hits)) : null;
    }

    private static function norm(string $p): string
    {
        $p = str_replace('ː', '', $p);

        return match ($p) {
            'r' => 'ɹ',
            'ɝ', 'ɚ' => 'ɜ',
            default => $p,
        };
    }
}
