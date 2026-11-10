<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;

/** Liga semanal: puntos (XP) de lunes a domingo. Solo aparecen quienes lo permiten, con nombre e inicial. */
class LeagueService
{
    public const TOP = 20;

    public function __construct(private SrsService $srs) {}

    public function week(User $user): array
    {
        $today = $this->srs->today($user);
        $start = $today->startOfWeek();
        $end = $start->addDays(6);

        $rows = DB::table('xp_days')->join('users', 'users.id', '=', 'xp_days.user_id')
            ->whereBetween('xp_days.day', [$start->toDateString(), $end->toDateString()])
            ->where(fn ($q) => $q->where('users.league_visible', true)->orWhere('users.id', $user->id))
            ->groupBy('users.id', 'users.name', 'users.email')
            ->selectRaw('users.id, users.name, users.email, sum(xp_days.xp) as xp')
            ->orderByDesc('xp')->orderBy('users.id')->get()
            ->reject(fn ($r) => str_ends_with((string) $r->email, '@'.DemoService::DOMAIN) && (int) $r->id !== $user->id)->values();

        $rank = $rows->search(fn ($r) => (int) $r->id === $user->id);

        return [
            'from' => $start->toDateString(),
            'to' => $end->toDateString(),
            'days_left' => (int) $today->diffInDays($end),
            'visible' => (bool) $user->league_visible,
            'me' => ['rank' => $rank === false ? null : $rank + 1, 'xp' => $rank === false ? 0 : (int) $rows[$rank]->xp],
            'players' => $rows->count(),
            'top' => $rows->take(self::TOP)->map(fn ($r, $i) => [
                'rank' => $i + 1,
                'name' => self::display($r->name),
                'xp' => (int) $r->xp,
                'me' => (int) $r->id === $user->id,
            ])->values(),
        ];
    }

    /** "Reynaldo Huerga" → "Reynaldo H." (nunca el correo ni el apellido completo). */
    public static function display(?string $name): string
    {
        $parts = preg_split('/\s+/', trim((string) $name)) ?: [];
        $first = $parts[0] ?? '';
        if ($first === '') {
            return 'Alumno';
        }

        return mb_substr($first, 0, 20).(isset($parts[1]) ? ' '.mb_strtoupper(mb_substr($parts[1], 0, 1)).'.' : '');
    }
}
