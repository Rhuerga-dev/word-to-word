<?php

namespace App\Services;

use App\Models\SpeakingSession;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Escalera de español: cuánto español usa la app con cada alumno (escalón 1–4) y cuánto lo pide él.
 * El escalón sale del nivel del alumno y sube solo cuando casi no pide español; también se puede fijar a mano.
 */
class SpanishService
{
    public const KINDS = ['translation', 'hint', 'explain', 'translate'];

    public function __construct(private SrsService $srs) {}

    /** Escalón según el nivel, sin contar el uso. */
    public function base(User $user): int
    {
        return (int) (config('spanish.base')[$user->cefr_level ?? 'A1'] ?? 1);
    }

    public function step(User $user): int
    {
        return $user->spanish_step ? max(1, min(4, (int) $user->spanish_step)) : $this->autoStep($user);
    }

    /** El automático: el del nivel, o uno más si la última semana estudió casi sin pedir español. */
    public function autoStep(User $user): int
    {
        $base = $this->base($user);
        $p = config('spanish.promote');
        $from = $this->srs->today($user)->subDays(6)->toDateString();
        $days = DB::table('xp_days')->where('user_id', $user->id)->where('day', '>=', $from)->where('xp', '>', 0)->count();
        $uses = (int) DB::table('spanish_uses')->where('user_id', $user->id)->whereDate('day', '>=', $from)->sum('count');

        return $days >= $p['days'] && $uses <= $p['max_uses'] ? min(4, $base + 1) : $base;
    }

    /** Idioma de las explicaciones del coach: es · simple (inglés sencillo) · en. */
    public function coachLang(User $user): string
    {
        return match ($this->step($user)) {
            1 => 'es',
            2 => 'simple',
            default => 'en',
        };
    }

    public function limit(int $step): ?int
    {
        return config('spanish.daily_limit')[$step] ?? null;
    }

    public function usesToday(User $user): int
    {
        return (int) DB::table('spanish_uses')->where('user_id', $user->id)->whereDate('day', $this->srs->today($user)->toDateString())->sum('count');
    }

    /**
     * Registra que pidió español. Devuelve si se le da (con el límite del escalón) y cuántas le quedan hoy.
     *
     * @return array{allowed: bool, left: ?int, used: int}
     */
    public function use(User $user, string $kind): array
    {
        $limit = $this->limit($this->step($user));
        $used = $this->usesToday($user);
        if ($limit !== null && $used >= $limit) {
            return ['allowed' => false, 'left' => 0, 'used' => $used];
        }
        $day = $this->srs->today($user)->toDateString();
        DB::table('spanish_uses')->insertOrIgnore(['user_id' => $user->id, 'day' => $day, 'kind' => $kind, 'count' => 0, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('spanish_uses')->where('user_id', $user->id)->whereDate('day', $day)->where('kind', $kind)->increment('count', 1, ['updated_at' => now()]);

        return ['allowed' => true, 'left' => $limit === null ? null : $limit - $used - 1, 'used' => $used + 1];
    }

    /** Días de estudio seguidos sin pedir español (hasta hoy, o ayer si hoy aún no estudió). */
    public function streak(User $user): int
    {
        $today = $this->srs->today($user);
        $studied = DB::table('xp_days')->where('user_id', $user->id)->where('xp', '>', 0)->where('day', '>=', $today->subDays(120)->toDateString())->pluck('day')->map(fn ($d) => substr((string) $d, 0, 10))->flip();
        $spanish = DB::table('spanish_uses')->where('user_id', $user->id)->where('count', '>', 0)->whereDate('day', '>=', $today->subDays(120)->toDateString())->pluck('day')->map(fn ($d) => substr((string) $d, 0, 10))->flip();
        $day = isset($studied[$today->toDateString()]) ? $today : $today->subDay();
        $n = 0;
        while (isset($studied[$day->toDateString()]) && ! isset($spanish[$day->toDateString()])) {
            $n++;
            $day = $day->subDay();
        }

        return $n;
    }

    /** Lo que ven las apps: escalón, si es automático, límite y uso, racha y la señal de traducción. */
    public function summary(User $user): array
    {
        $step = $this->step($user);
        $limit = $this->limit($step);
        $today = $this->usesToday($user);
        $from = $this->srs->today($user)->subDays(6)->toDateString();
        $sessions = SpeakingSession::where('user_id', $user->id)->whereDate('day', '>=', $from)->where('reaction_turns', '>', 0)->get(['reaction_ms', 'reaction_turns']);
        $turns = $sessions->sum('reaction_turns');
        $reaction = $turns ? round($sessions->sum('reaction_ms') / $turns / 1000, 1) : null;

        return [
            'step' => $step,
            'auto' => $user->spanish_step === null,
            'base' => $this->base($user),
            'ui' => $step >= 3 ? 'en' : 'es',
            'coach' => $this->coachLang($user),
            'limit' => $limit,
            'today' => $today,
            'left' => $limit === null ? null : max(0, $limit - $today),
            'week' => (int) DB::table('spanish_uses')->where('user_id', $user->id)->whereDate('day', '>=', $from)->sum('count'),
            'streak' => $this->streak($user),
            'reaction' => $reaction,
            'translating' => $reaction !== null && $reaction > (float) config('spanish.translating_seconds'),
        ];
    }
}
