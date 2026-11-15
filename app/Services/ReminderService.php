<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserWord;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Recordatorio inteligente:
 * - Hora: la mediana de cuándo empieza a practicar (primer XP de cada día, últimos 21 días).
 *   Con menos de 3 días de datos se usa la hora que eligió.
 * - Texto: la palabra concreta que le toca hoy.
 */
class ReminderService
{
    public const MIN_DAYS = 3;

    /** Minutos de margen tras su hora habitual: si a esa hora no empezó, se le avisa. */
    public const GRACE_MINUTES = 30;

    public function __construct(private SrsService $srs) {}

    /** Hora habitual (HH:MM, en su zona horaria) o null si aún no hay datos suficientes. */
    public function usualTime(User $user): ?string
    {
        $tz = $user->timezone ?: config('vocab.timezone');
        $minutes = DB::table('xp_days')
            ->where('user_id', $user->id)
            ->where('created_at', '>=', now()->subDays(21))
            ->whereNotNull('created_at')
            ->pluck('created_at')
            ->map(function ($at) use ($tz) {
                $local = CarbonImmutable::parse($at, 'UTC')->setTimezone($tz);

                return $local->hour * 60 + $local->minute;
            })
            ->sort()->values();

        if ($minutes->count() < self::MIN_DAYS) {
            return null;
        }
        $n = $minutes->count();
        $median = $n % 2 ? $minutes[intdiv($n, 2)] : intdiv($minutes[$n / 2 - 1] + $minutes[$n / 2], 2);
        $median = (int) (round($median / 15) * 15) % 1440;   // en cuartos de hora

        return sprintf('%02d:%02d', intdiv($median, 60), $median % 60);
    }

    /** Hora a la que se envía hoy (HH:MM). */
    public function sendTime(User $user): string
    {
        if ($user->reminder_auto && ($usual = $this->usualTime($user))) {
            [$h, $m] = array_map('intval', explode(':', $usual));
            $at = ($h * 60 + $m + self::GRACE_MINUTES) % 1440;

            return sprintf('%02d:%02d', intdiv($at, 60), $at % 60);
        }

        return $user->reminder_time ?: '19:00';
    }

    /** La palabra que le toca hoy: primero un repaso pendiente; si no hay, la próxima nueva. */
    public function wordOfToday(User $user): ?string
    {
        $today = $this->srs->today($user);
        $due = UserWord::with('word')->where('user_id', $user->id)->whereNotNull('introduced_at')
            ->whereDate('next_review', '<=', $today)
            ->orderBy('next_review')->orderBy('level')->first();
        if ($due?->word) {
            return $due->word->word;
        }

        return $this->srs->queue($user)['new']->first()?->word;
    }
}
