<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Puntos (XP). Los da siempre el servidor, cuando pasa algo de verdad (repasar, hablar, aprobar un taller…),
 * nunca porque la app lo pida. Cada fuente tiene un tope por día para que no se pueda "farmear".
 */
class XpService
{
    /** Puntos por acción y tope diario de cada fuente. */
    public const POINTS = [
        'learn' => 5, 'review' => 3, 'review_again' => 1, 'mistake' => 5, 'mistake_fail' => 1,
        'pronunciation' => 1, 'lab' => 15, 'session' => 10,
    ];

    public const DAILY_CAP = [
        'learn' => 250, 'review' => 300, 'review_again' => 50, 'mistake' => 150, 'mistake_fail' => 20,
        'pronunciation' => 60, 'lab' => 60, 'session' => 30, 'speak' => 300,
    ];

    public function __construct(private SrsService $srs) {}

    /** Suma puntos de una fuente (respetando su tope de hoy). Devuelve los puntos que de verdad se sumaron. */
    public function add(User $user, string $source, ?int $points = null): int
    {
        $points ??= self::POINTS[$source] ?? 0;
        if ($points <= 0) {
            return 0;
        }
        $day = $this->srs->today($user)->toDateString();

        return DB::transaction(function () use ($user, $source, $points, $day) {
            $row = DB::table('xp_days')->where('user_id', $user->id)->where('day', $day)->lockForUpdate()->first();
            $by = $row && $row->by_source ? json_decode($row->by_source, true) : [];
            $cap = self::DAILY_CAP[$source] ?? 100;
            $give = max(0, min($points, $cap - (int) ($by[$source] ?? 0)));
            if ($give === 0) {
                return 0;
            }
            $by[$source] = (int) ($by[$source] ?? 0) + $give;
            $values = ['xp' => (int) ($row->xp ?? 0) + $give, 'by_source' => json_encode($by), 'updated_at' => now()];
            if ($row) {
                DB::table('xp_days')->where('id', $row->id)->update($values);
            } else {
                DB::table('xp_days')->insert($values + ['user_id' => $user->id, 'day' => $day, 'created_at' => now()]);
            }
            $user->increment('xp_total', $give);
            // Practicar cualquier cosa cuenta para la racha (no solo las fichas).
            $this->srs->markStudied($user, $this->srs->today($user));

            return $give;
        });
    }

    /** Puntos por hablar: 10 por minuto de tu voz (mínimo 2 si dijiste algo). */
    public function speak(User $user, int $speechMs, int $words): int
    {
        if ($words <= 0) {
            return 0;
        }

        return $this->add($user, 'speak', max(2, (int) round($speechMs / 60000 * 10)));
    }

    public function today(User $user): array
    {
        $day = $this->srs->today($user);
        $row = DB::table('xp_days')->where('user_id', $user->id)->where('day', $day->toDateString())->first();
        $goal = (int) ($user->xp_goal ?: 100);
        $week = DB::table('xp_days')->where('user_id', $user->id)
            ->where('day', '>=', $day->subDays(6)->toDateString())->pluck('xp', 'day');

        return [
            'xp' => (int) ($row->xp ?? 0),
            'goal' => $goal,
            'total' => (int) $user->xp_total,
            'sessions' => (int) ($row->sessions ?? 0),
            'week' => collect(range(6, 0))->map(fn ($i) => [
                'day' => $d = $day->subDays($i)->toDateString(),
                'xp' => (int) ($week[$d] ?? 0),
            ])->values()->all(),
        ];
    }
}
