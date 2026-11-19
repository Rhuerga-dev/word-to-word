<?php

namespace App\Services;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Experimento A/B del Modo Brainy: ¿quien tiene a Brainy como pantalla principal practica y aprende más?
 *
 * - Grupo estable sin tabla: crc32("brainy-ab:" . id) % 2 → 1 = «brainy», 0 = «control».
 * - Apagado (o antes de la fecha de inicio), todo queda como siempre: nadie tiene grupo y nada se guarda.
 * - La demo y las cuentas de `exclude_ids` no entran.
 * - Solo cuentan los alumnos cuya APP informó de su modo (la web no tiene Brainy).
 */
class BrainyExperiment
{
    public const NAME = 'brainy';

    public const GROUPS = ['brainy', 'control'];

    public function __construct(private SrsService $srs) {}

    /** ¿Está en marcha hoy? Encendido y con fecha de inicio válida que ya llegó. */
    public function active(): bool
    {
        $start = $this->start();

        return (bool) config('experiments.brainy.enabled') && $start !== null
            && $start->lessThanOrEqualTo(CarbonImmutable::today(config('vocab.timezone')));
    }

    public function start(): ?CarbonImmutable
    {
        $raw = (string) config('experiments.brainy.start');
        if (! preg_match('/^\d{4}-\d{2}-\d{2}$/', $raw)) {
            return null;
        }
        try {
            return CarbonImmutable::createFromFormat('!Y-m-d', $raw, config('vocab.timezone')) ?: null;
        } catch (\Throwable) {
            return null;
        }
    }

    /** El grupo que le tocaría a ese id (siempre el mismo). */
    public static function groupOf(int $userId): string
    {
        return crc32('brainy-ab:'.$userId) % 2 === 1 ? 'brainy' : 'control';
    }

    /** El grupo del alumno, o null si no participa (experimento apagado, demo o cuenta excluida). */
    public function group(?User $user): ?string
    {
        if (! $user || ! $this->active() || DemoService::isDemo($user)
            || in_array($user->id, (array) config('experiments.brainy.exclude_ids'), true)) {
            return null;
        }

        return self::groupOf($user->id);
    }

    /** Lo que va en /api/me: true = Modo Brainy encendido por defecto; null = sin experimento (la app sigue igual). */
    public function default(?User $user): ?bool
    {
        $group = $this->group($user);

        return $group === null ? null : $group === 'brainy';
    }

    /**
     * La app informa del modo real. Devuelve false si el alumno no participa (no se guarda nada).
     * $opened = acaba de abrir la pantalla de Brainy.
     */
    public function record(User $user, bool $mode, bool $changed, bool $opened = false): bool
    {
        $group = $this->group($user);
        if ($group === null) {
            return false;
        }
        $row = $this->participant($user, $group);
        $values = ['mode' => $mode, 'changed' => $changed || (bool) $row->changed, 'reported_at' => now(), 'updated_at' => now()];
        // Se apunta el momento en que cambió a mano (y cada vez que vuelve a cambiar después).
        if ($changed && (! $row->changed || ($row->mode !== null && (bool) $row->mode !== $mode))) {
            $values['changed_at'] = now();
        }
        DB::table('experiment_participants')->where('id', $row->id)->update($values);
        if ($opened) {
            DB::table('experiment_participants')->where('id', $row->id)->increment('opens');
        }

        return true;
    }

    /** Un botón de cuidado pulsado (POST /api/pet/{action}). */
    public function careTap(User $user): void
    {
        $group = $this->group($user);
        if ($group !== null) {
            DB::table('experiment_participants')->where('id', $this->participant($user, $group)->id)->increment('care_taps');
        }
    }

    private function participant(User $user, string $group): object
    {
        $where = ['user_id' => $user->id, 'experiment' => self::NAME];
        DB::table('experiment_participants')->insertOrIgnore($where + [
            'group' => $group, 'entered_day' => $this->srs->today($user)->toDateString(), 'created_at' => now(), 'updated_at' => now(),
        ]);

        return DB::table('experiment_participants')->where($where)->first();
    }

    // ---------- Informe ----------

    /**
     * Compara los dos grupos desde que cada alumno entró al experimento. Solo cifras, sin datos personales.
     * Las métricas principales son «practice» y «learning»; «brainy» (clics) es solo contexto.
     */
    public function report(?CarbonImmutable $today = null): array
    {
        $today ??= CarbonImmutable::today(config('vocab.timezone'));
        $min = max(1, (int) config('experiments.brainy.min_users'));
        $start = $this->start();
        $rows = DB::table('experiment_participants')->where('experiment', self::NAME)
            ->when($start, fn ($q) => $q->where('entered_day', '>=', $start->toDateString()))->get();

        $groups = [];
        foreach (self::GROUPS as $name) {
            $groups[$name] = $this->groupReport($rows->where('group', $name)->values(), $today);
        }
        $smallest = min(array_column($groups, 'users'));
        $days = $start ? max(0, (int) $start->diffInDays($today)) : 0;

        $warning = null;
        if (! $this->active()) {
            $warning = 'El experimento está apagado: no hay grupos y la app se comporta como siempre.';
        } elseif ($smallest < $min) {
            $warning = "Muy pocos alumnos para sacar conclusiones: el grupo más pequeño tiene {$smallest} y hacen falta al menos {$min} por grupo. Las diferencias pueden ser casualidad.";
        } elseif ($days < 14) {
            $warning = "El experimento lleva {$days} días: espera al menos 14 (mejor 21) antes de decidir.";
        }

        return [
            'experiment' => self::NAME,
            'enabled' => (bool) config('experiments.brainy.enabled'),
            'active' => $this->active(),
            'start' => $start?->toDateString(),
            'days_running' => $days,
            'min_users' => $min,
            'enough_data' => $this->active() && $smallest >= $min && $days >= 14,
            'warning' => $warning,
            'primary_metrics' => ['practice', 'learning'],
            'groups' => $groups,
        ];
    }

    /** @param \Illuminate\Support\Collection<int, object> $rows */
    private function groupReport($rows, CarbonImmutable $today): array
    {
        $pct = fn (int $ok, int $total): ?int => $total > 0 ? (int) round($ok / $total * 100) : null;
        $ids = $rows->pluck('user_id')->all();
        $entered = $rows->mapWithKeys(fn ($r) => [$r->user_id => substr((string) $r->entered_day, 0, 10)]);
        $since = fn ($userId, $day) => isset($entered[$userId]) && substr((string) $day, 0, 10) >= $entered[$userId];

        // Días activos (con puntos) de cada alumno desde que entró.
        $xp = DB::table('xp_days')->whereIn('user_id', $ids)->where('xp', '>', 0)->get(['user_id', 'day', 'by_source', 'sessions'])
            ->filter(fn ($r) => $since($r->user_id, $r->day));
        $activeDays = $xp->groupBy('user_id')->map(fn ($g) => $g->map(fn ($r) => substr((string) $r->day, 0, 10))->unique()->flip());

        // Retención: de los que ya cumplieron el día N completo, cuántos practicaron ese día.
        $retention = [];
        foreach ([1, 7, 14] as $n) {
            $of = $ok = 0;
            foreach ($entered as $userId => $day) {
                $target = CarbonImmutable::parse($day)->addDays($n)->toDateString();
                if ($target < $today->toDateString()) {
                    $of++;
                    $ok += isset($activeDays[$userId][$target]) ? 1 : 0;
                }
            }
            $retention["d{$n}"] = ['active' => $ok, 'of' => $of, 'percent' => $pct($ok, $of)];
        }

        // Semanas de alumno: cuánto tiempo lleva cada uno dentro (mínimo 1 día). Todo lo de «practice» va por alumno y semana.
        $weeks = 0.0;
        foreach ($entered as $day) {
            $weeks += max(1, (int) CarbonImmutable::parse($day)->diffInDays($today) + 1) / 7;
        }
        $perWeek = fn (float|int $total): ?float => $weeks > 0 ? round($total / $weeks, 1) : null;

        // Práctica real, a partir de los puntos que da el servidor por cada ejercicio hecho de verdad.
        $points = [];
        foreach ($xp as $r) {
            foreach ((array) json_decode((string) $r->by_source, true) as $source => $value) {
                $points[$source] = ($points[$source] ?? 0) + (int) $value;
            }
        }
        $per = XpService::POINTS;
        $goodReviews = intdiv($points['review'] ?? 0, $per['review']);
        $failedReviews = intdiv($points['review_again'] ?? 0, $per['review_again']);
        $newWords = DB::table('user_words')->whereIn('user_id', $ids)->whereNotNull('introduced_at')->get(['user_id', 'introduced_at'])
            ->filter(fn ($r) => $since($r->user_id, $r->introduced_at))->count();
        $listening = DB::table('listening_days')->whereIn('user_id', $ids)->get(['user_id', 'day', 'ear_ok', 'ear_fail'])
            ->filter(fn ($r) => $since($r->user_id, $r->day));
        $earOk = (int) $listening->sum('ear_ok');
        $earTotal = $earOk + (int) $listening->sum('ear_fail');
        $speaking = DB::table('speaking_sessions')->whereIn('user_id', $ids)->get(['id', 'user_id', 'day', 'words', 'speech_ms'])
            ->filter(fn ($r) => $since($r->user_id, $r->day));
        $spokenWords = (int) $speaking->sum('words');
        $mistakes = DB::table('speaking_mistakes')->whereIn('speaking_session_id', $speaking->pluck('id')->all())->count();
        $speakingMinutes = $speaking->sum('speech_ms') / 60000;
        $mistakeDrills = intdiv($points['mistake'] ?? 0, $per['mistake']) + intdiv($points['mistake_fail'] ?? 0, $per['mistake_fail']);
        $exercises = $newWords + $goodReviews + $failedReviews + $earTotal + $mistakeDrills
            + intdiv($points['lab'] ?? 0, $per['lab']) + $speaking->where('words', '>', 0)->count();
        $strong = DB::table('user_words')->whereIn('user_id', $ids)->where('stability', '>=', (float) config('pet.strong_days', 21))->count();
        $users = count($ids);

        return [
            'users' => $users,
            'retention' => $retention,
            'practice' => [   // por alumno y semana
                'active_days_per_week' => $perWeek($activeDays->sum(fn ($d) => $d->count())),
                'sessions_per_week' => $perWeek((int) $xp->sum('sessions')),
                'exercises_per_week' => $perWeek($exercises),
                'new_words_per_week' => $perWeek($newWords),
                'reviews_per_week' => $perWeek($goodReviews + $failedReviews),
                'ear_per_week' => $perWeek($earTotal),
                'speaking_minutes_per_week' => $perWeek($speakingMinutes),
            ],
            'learning' => [
                'ear_accuracy' => ['percent' => $pct($earOk, $earTotal), 'of' => $earTotal],
                'vocab_accuracy' => ['percent' => $pct($goodReviews, $goodReviews + $failedReviews), 'of' => $goodReviews + $failedReviews],
                'speaking_clean' => ['percent' => $pct(max(0, $spokenWords - $mistakes), $spokenWords), 'words' => $spokenWords],
                'strong_words_per_user' => $users > 0 ? round($strong / $users, 1) : null,
            ],
            'brainy' => [     // contexto, no la métrica principal
                'mode_on' => $rows->where('mode', 1)->count(),
                'mode_off' => $rows->filter(fn ($r) => $r->mode !== null && ! $r->mode)->count(),
                'turned_on_by_hand' => $rows->filter(fn ($r) => $r->changed && $r->mode)->count(),
                'turned_off_by_hand' => $rows->filter(fn ($r) => $r->changed && $r->mode !== null && ! $r->mode)->count(),
                'opens' => (int) $rows->sum('opens'),
                'care_taps' => (int) $rows->sum('care_taps'),
            ],
        ];
    }
}
