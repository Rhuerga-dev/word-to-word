<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserWord;
use Illuminate\Support\Facades\DB;

/**
 * La mascota Brainy: aprende lo que TÚ aprendes.
 *
 * Su estado sale de lo que W2W ya sabe del alumno (no guarda nada nuevo):
 *   - palabras aprendidas y cuántas se recuerdan bien (FSRS),
 *   - unidades del Camino completas,
 *   - la racha.
 * Cada cosa enciende una zona de su cerebro y, juntas, dan los puntos con los que crece.
 * La mascota nunca muere ni se pone triste: si un día no estudias, solo deja de crecer.
 */
class PetService
{
    public function __construct(private SrsService $srs) {}

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

        return ['name' => 'Brainy', 'points' => $points, 'stage' => $this->stage($points), 'regions' => $regions];
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
    private function stage(int $points): array
    {
        $stages = config('pet.stages');
        $keys = array_keys($stages);
        $index = 0;
        foreach ($keys as $i => $key) {
            if ($points >= $stages[$key]) {
                $index = $i;
            }
        }
        $from = $stages[$keys[$index]];
        $next = isset($keys[$index + 1]) ? $stages[$keys[$index + 1]] : null;

        return [
            'index' => $index,
            'key' => $keys[$index],
            'count' => count($keys),
            'from' => $from,
            'next' => $next,
            'progress' => $next === null ? 1.0 : round(($points - $from) / max(1, $next - $from), 3),
        ];
    }
}
