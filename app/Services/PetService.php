<?php

namespace App\Services;

use App\Models\SpeakingMistake;
use App\Models\User;
use App\Models\UserWord;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * La mascota Brainy: aprende lo que TÚ aprendes.
 *
 * Lo que sabe sale de lo que W2W ya sabe del alumno:
 *   - palabras aprendidas y cuántas se recuerdan bien (FSRS),
 *   - unidades del Camino completas,
 *   - la racha.
 * Cada cosa enciende una zona de su cerebro y, juntas, dan los puntos con los que crece.
 * Sus cuidados (comida, ánimo, limpieza, salud) los lleva PetCare. Nunca muere y su etapa nunca baja.
 */
class PetService
{
    public function __construct(private SrsService $srs, private PetCare $care, private EarService $ear) {}

    public function state(User $user): array
    {
        $learned = UserWord::where('user_id', $user->id)->whereNotNull('introduced_at');
        $words = (clone $learned)->count();
        $strong = $this->strong($learned);
        $units = DB::table('unit_progress')->where('user_id', $user->id)->whereNotNull('passed_at')->count();
        $streak = $this->srs->streak($user, $this->srs->today($user));

        $p = config('pet.points');
        $points = $words * $p['word'] + $strong * $p['strong'] + $units * $p['unit']
            + min($streak, $p['streak_max']) * $p['streak_day'];

        $t = config('pet.targets');
        $regions = [
            'words' => $this->region($words, $t['words']),
            'memory' => $this->region($strong, $t['memory']),
            'path' => $this->region($units, $t['path']),
            'habit' => $this->region($streak, $t['habit']),
        ];
        // Las conexiones: se encienden a medida que se enciende todo lo demás.
        $regions['links'] = ['level' => round(array_sum(array_column($regions, 'level')) / count($regions), 3)];

        $state = ['name' => 'Brainy', 'points' => $points, 'stage' => $this->stage($points), 'regions' => $regions];
        // Los cuidados. Si fallan (p. ej. falta la tabla), la mascota sigue saliendo como antes, sin barras.
        try {
            $care = $this->care->state($user, $state['stage']['index'], array_keys(config('pet.stages')));
            $state['stage'] = $this->stage($points, $care['stage']);
            $state['care'] = $care['care'];
        } catch (Throwable $e) {
            report($e);
        }

        return $state;
    }

    /**
     * Un botón de cuidado: dice qué ejercicio toca (nunca da corazones gratis; los da hacer el ejercicio).
     * `go`: new · reviews · ear · mistakes · sound · null (no hay nada que hacer ahora).
     */
    public function act(User $user, string $action): array
    {
        $queue = $this->srs->queue($user);
        $reviews = $queue['reviews']->count();
        $mistakes = fn () => SpeakingMistake::where('user_id', $user->id)->whereNull('mastered_on')
            ->whereDate('next_review', '<=', $this->srs->today($user)->toDateString())->exists();

        $go = match ($action) {
            'feed' => $queue['new']->isNotEmpty() ? 'new' : ($reviews > 0 ? 'reviews' : null),
            'play' => count($this->ear->due($user, 1)) > 0 ? 'ear' : 'sound',
            'clean' => $reviews > 0 ? 'reviews' : ($mistakes() ? 'mistakes' : null),
            'medicine' => 'sound',
        };

        return ['action' => $action, 'go' => $go, 'pet' => $this->state($user)];
    }

    /**
     * Palabras que se recuerdan bien. Las de antes de FSRS no tienen stability:
     * cuentan por su nivel de repaso, como hace SrsService (el salto de ese nivel hace de stability).
     */
    private function strong($learned): int
    {
        $days = (float) config('pet.strong_days');
        $intervals = config('vocab.intervals');
        $level = count($intervals);                     // si ningún salto llega, ningún nivel cuenta
        foreach ($intervals as $i => $interval) {
            if ($interval >= $days) {
                $level = $i;
                break;
            }
        }

        return (clone $learned)->where(fn ($q) => $q->where('stability', '>=', $days)
            ->orWhere(fn ($q) => $q->whereNull('stability')->where('level', '>=', $level)))->count();
    }

    /** @return array{count: int, target: int, level: float} */
    private function region(int $count, int $target): array
    {
        return ['count' => $count, 'target' => $target, 'level' => round(min(1, $count / max(1, $target)), 3)];
    }

    /** En qué etapa está, cuánto lleva de ella (0–1) y cuántos puntos pide la siguiente (null = la última). */
    private function stage(int $points, int $atLeast = 0): array
    {
        $stages = config('pet.stages');
        $keys = array_keys($stages);
        $index = 0;
        foreach ($keys as $i => $key) {
            if ($points >= $stages[$key]) {
                $index = $i;
            }
        }
        // La etapa nunca baja: si ya llegó más lejos, se queda ahí (con la barra de la etapa vacía).
        $index = min(count($keys) - 1, max($index, $atLeast));
        $from = $stages[$keys[$index]];
        $next = isset($keys[$index + 1]) ? $stages[$keys[$index + 1]] : null;

        return [
            'index' => $index,
            'key' => $keys[$index],
            'count' => count($keys),
            'from' => $from,
            'next' => $next,
            'progress' => $next === null ? 1.0 : round(max(0, min(1, ($points - $from) / max(1, $next - $from))), 3),
        ];
    }
}
