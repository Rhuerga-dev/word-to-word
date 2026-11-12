<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Coste de IA por alumno (de la tabla ai_usage): total, por tipo de llamada y por alumno activo,
 * con la proyección a un mes de 20 días de estudio. Las cuentas demo se cuentan aparte.
 */
class AiCosts extends Command
{
    protected $signature = 'ai:costs {--days=30 : Días hacia atrás}';

    protected $description = 'Muestra cuánto cuesta la IA (Claude y Azure) por alumno';

    public function handle(): int
    {
        $since = now()->subDays((int) $this->option('days') - 1)->toDateString();
        $rows = DB::table('ai_usage')->where('day', '>=', $since);

        $total = (float) (clone $rows)->sum('cost_usd');
        $this->info(sprintf('Últimos %d días: %s USD en total.', $this->option('days'), $this->usd($total)));

        $this->table(['Proveedor', 'Tipo', 'Llamadas', 'Audio (min)', 'Tokens', 'USD'],
            (clone $rows)->selectRaw('provider, kind, count(*) n, sum(audio_ms) ms, sum(input_tokens + output_tokens) tk, sum(cost_usd) c')
                ->groupBy('provider', 'kind')->orderByDesc('c')->get()
                ->map(fn ($r) => [$r->provider, $r->kind, $r->n, round($r->ms / 60000, 1), $r->tk, $this->usd($r->c)])->all());

        // Por alumno y día: el gasto de cada día con actividad (las demo, aparte).
        $days = (clone $rows)->whereNotNull('ai_usage.user_id')
            ->join('users', 'users.id', '=', 'ai_usage.user_id')
            ->selectRaw("ai_usage.user_id, ai_usage.day, sum(cost_usd) c, (users.email like 'demo%') demo")
            ->groupBy('ai_usage.user_id', 'ai_usage.day', 'demo')->get();
        $server = (float) (clone $rows)->whereNull('user_id')->sum('cost_usd');

        foreach ([0 => 'Alumnos', 1 => 'Demo'] as $isDemo => $label) {
            $d = $days->where('demo', $isDemo);
            if ($d->isEmpty()) {
                continue;
            }
            $perDay = $d->avg('c');
            $sorted = $d->pluck('c')->sort()->values();
            $p90 = $sorted[(int) floor(0.9 * ($sorted->count() - 1))];
            $this->line(sprintf('%s: %d con actividad, %d días-alumno. Por día de estudio: media %s USD, el 90 %% gasta menos de %s USD.',
                $label, $d->pluck('user_id')->unique()->count(), $d->count(), $this->usd($perDay), $this->usd($p90)));
            if (! $isDemo) {
                $this->line(sprintf('  → Un mes con 20 días de estudio: unos %s USD por alumno (los que más usan: %s USD).', $this->usd($perDay * 20), $this->usd($p90 * 20)));
            }
        }
        $this->line(sprintf('Tareas del servidor (palabras, traducciones; se reparten entre todos): %s USD.', $this->usd($server)));

        return self::SUCCESS;
    }

    private function usd(float $v): string
    {
        return $v >= 1 ? number_format($v, 2) : number_format($v, 4);
    }
}
