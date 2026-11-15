<?php

namespace App\Console\Commands;

use App\Services\DemoService;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Métricas de uso para el panel de Huerga Labs (sin datos personales: solo cifras).
 * Escribe storage/app/metrics.json; el panel lo lee de esa ruta fija.
 * "Activo" = ganó XP ese día (estudió, habló o repasó). Los alumnos de la demo no cuentan.
 */
class MetricsSnapshot extends Command
{
    protected $signature = 'metrics:snapshot';

    protected $description = 'Calcula usuarios activos, retención y sesiones para el panel';

    public function handle(): int
    {
        $data = $this->compute(CarbonImmutable::today(config('vocab.timezone')));
        // Escribe en un temporal y lo renombra: el panel nunca lee un archivo a medias.
        $path = storage_path('app/metrics.json');
        file_put_contents($path.'.tmp', json_encode($data, JSON_PRETTY_PRINT));
        rename($path.'.tmp', $path);
        $this->info("Activos hoy: {$data['active_today']} · 7 días: {$data['active_7d']} · usuarios: {$data['users']}");

        return self::SUCCESS;
    }

    public function compute(CarbonImmutable $today): array
    {
        $demoIds = DB::table('users')->where('email', 'like', '%@'.DemoService::DOMAIN)->pluck('id');
        $xp = fn () => DB::table('xp_days')->whereNotIn('user_id', $demoIds);

        // Días activos de cada usuario (de los últimos 60), para la retención.
        $daysByUser = $xp()->where('day', '>=', $today->subDays(60)->toDateString())->where('xp', '>', 0)
            ->get(['user_id', 'day'])
            ->groupBy('user_id')
            ->map(fn ($rows) => $rows->map(fn ($r) => substr((string) $r->day, 0, 10))->unique()->flip());

        $daily = [];
        for ($i = 13; $i >= 0; $i--) {
            $d = $today->subDays($i)->toDateString();
            $rows = $xp()->whereDate('day', $d)->where('xp', '>', 0);
            $daily[] = [
                'day' => $d,
                'active' => (clone $rows)->distinct()->count('user_id'),
                'sessions' => (int) (clone $rows)->sum('sessions'),
            ];
        }

        return [
            'app' => 'w2w',
            'generated_at' => now()->toIso8601String(),
            'users' => DB::table('users')->whereNotIn('id', $demoIds)->count(),
            'new_users_7d' => DB::table('users')->whereNotIn('id', $demoIds)->where('created_at', '>=', now()->subDays(7))->count(),
            'active_today' => end($daily)['active'],
            'active_7d' => $this->activeSince($daysByUser, $today->subDays(6)),
            'active_30d' => $this->activeSince($daysByUser, $today->subDays(29)),
            'sessions_today' => end($daily)['sessions'],
            'retention_d1' => $this->retention($daysByUser, $today, 1),
            'retention_d7' => $this->retention($daysByUser, $today, 7),
            'daily' => $daily,
        ];
    }

    private function activeSince($daysByUser, CarbonImmutable $from): int
    {
        $from = $from->toDateString();

        return $daysByUser->filter(fn ($days) => $days->keys()->contains(fn ($d) => $d >= $from))->count();
    }

    /**
     * % de usuarios que volvieron N días después de su primer día activo
     * (solo los que empezaron hace más de N días, dentro de los últimos 60).
     * null si aún no hay nadie que medir.
     *
     * @return array{percent: int|null, of: int}
     */
    private function retention($daysByUser, CarbonImmutable $today, int $n): array
    {
        $eligible = 0;
        $back = 0;
        foreach ($daysByUser as $days) {
            $first = CarbonImmutable::parse($days->keys()->sort()->first());
            if ($first->addDays($n)->greaterThanOrEqualTo($today)) {
                continue;   // aún no pasó el día N completo
            }
            $eligible++;
            if ($days->has($first->addDays($n)->toDateString())) {
                $back++;
            }
        }

        return ['percent' => $eligible ? (int) round($back / $eligible * 100) : null, 'of' => $eligible];
    }
}
