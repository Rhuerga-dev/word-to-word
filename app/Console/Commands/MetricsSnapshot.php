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
            // Capa 2 (¿aprenden?): aciertos por habilidad, dónde se atascan y racha. Separado para no tocar lo de arriba.
            'learning' => $this->learning($demoIds, $today),
        ];
    }

    /**
     * Señales de aprendizaje (sin datos personales): aciertos de Oído/Vocabulario/Hablar,
     * las palabras que más se fallan y cómo va la racha. Los de la demo no cuentan.
     *
     * @param  \Illuminate\Support\Collection<int, int>  $demoIds
     */
    private function learning($demoIds, CarbonImmutable $today): array
    {
        $from = $today->subDays(6)->toDateString();   // últimos 7 días (incluye hoy)
        $pct = fn (int $ok, int $total): ?int => $total > 0 ? (int) round($ok / $total * 100) : null;

        // Oído: aciertos al reconocer de oído (7 días) y cuántas veces pidió repetir.
        $ear = DB::table('listening_days')->whereNotIn('user_id', $demoIds)->where('day', '>=', $from)
            ->selectRaw('COALESCE(SUM(ear_ok),0) ok, COALESCE(SUM(ear_fail),0) fail, COALESCE(SUM(repeats),0) repeats')->first();
        $earTotal = (int) $ear->ok + (int) $ear->fail;

        // Vocabulario: aciertos de repaso (contador acumulado de cada palabra).
        $vocab = DB::table('user_words')->whereNotIn('user_id', $demoIds)
            ->selectRaw('COALESCE(SUM(reviews),0) reviews, COALESCE(SUM(fails),0) fails')->first();

        // Hablar: limpieza al hablar (7 días) = palabras dichas sin error / palabras dichas.
        $spokenWords = (int) DB::table('speaking_sessions')->whereNotIn('user_id', $demoIds)->where('day', '>=', $from)->sum('words');
        $mistakes = (int) DB::table('speaking_mistakes')->whereNotIn('user_id', $demoIds)
            ->where('created_at', '>=', $today->subDays(6)->startOfDay())->count();

        // Dónde se atascan: las 5 palabras que más se fallan (entre todos).
        $stuck = DB::table('user_words')->whereNotIn('user_words.user_id', $demoIds)
            ->join('words', 'words.id', '=', 'user_words.word_id')
            ->where('user_words.fails', '>', 0)
            ->groupBy('words.word')
            ->orderByRaw('SUM(user_words.fails) DESC')
            ->limit(5)->get(['words.word', DB::raw('SUM(user_words.fails) as fails')])
            ->map(fn ($r) => ['word' => $r->word, 'fails' => (int) $r->fails])->all();

        // Racha: media de los que llevan racha, y cuántos tienen protector disponible.
        $base = DB::table('users')->whereNotIn('id', $demoIds);
        $avgStreak = (float) (clone $base)->where('streak', '>', 0)->avg('streak');

        return [
            'ear_accuracy' => ['percent' => $pct((int) $ear->ok, $earTotal), 'of' => $earTotal, 'repeats' => (int) $ear->repeats],
            'vocab_accuracy' => ['percent' => $pct((int) $vocab->reviews - (int) $vocab->fails, (int) $vocab->reviews), 'of' => (int) $vocab->reviews],
            'speaking_clean' => ['percent' => $pct(max(0, $spokenWords - $mistakes), $spokenWords), 'words' => $spokenWords, 'mistakes' => $mistakes],
            'top_failed_words' => $stuck,
            'avg_streak' => round($avgStreak, 1),
            'users_with_freeze' => (int) (clone $base)->where('streak_freezes', '>', 0)->count(),
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
