<?php

namespace App\Console\Commands;

use App\Models\Word;
use App\Services\UnitService;
use Illuminate\Console\Command;

/**
 * Crea las palabras de las unidades del Camino que todavía no existen (y luego `words:enrich` les pone traducción).
 *
 *   php artisan units:sync
 */
class SyncUnitWords extends Command
{
    protected $signature = 'units:sync';

    protected $description = 'Crea las palabras que faltan de las unidades del Camino y las enriquece con la IA';

    public function handle(): int
    {
        $created = 0;
        foreach (config('units.levels', []) as $units) {
            foreach ($units as $u) {
                foreach ($u['words'] ?? [] as $w) {
                    $word = Word::firstOrCreate(['word' => mb_strtolower($w)], ['rank' => 950000, 'source' => UnitService::SOURCE]);
                    $created += $word->wasRecentlyCreated ? 1 : 0;
                }
            }
        }
        $this->info("Palabras nuevas para el Camino: {$created}.");
        if ($created || Word::where('source', UnitService::SOURCE)->whereNull('translation')->exists()) {
            $this->call('words:enrich');
        }

        return self::SUCCESS;
    }
}
