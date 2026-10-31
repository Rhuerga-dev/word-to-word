<?php

namespace App\Console\Commands;

use App\Models\Word;
use App\Services\ClaudeService;
use Illuminate\Console\Command;
use Throwable;

/**
 * Llena traducción y ejemplo de las palabras que no los tienen, por lotes, usando Claude.
 * Solo las palabras enriquecidas aparecen como "nuevas" en la app.
 *
 *   php artisan words:enrich            (todas las pendientes)
 *   php artisan words:enrich --limit=100
 */
class EnrichWords extends Command
{
    protected $signature = 'words:enrich {--limit=0 : Máximo de palabras a procesar} {--batch=25}';

    protected $description = 'Agrega traducción y ejemplo a las palabras pendientes con la API de Claude';

    public function handle(ClaudeService $claude): int
    {
        if (! $claude->enabled()) {
            $this->error('Falta ANTHROPIC_API_KEY en .env');

            return self::FAILURE;
        }

        $query = Word::whereNull('translation')->orderBy('rank');
        if ($limit = (int) $this->option('limit')) {
            $query->limit($limit);
        }
        $pending = $query->get();

        if ($pending->isEmpty()) {
            $this->info('No hay palabras pendientes.');

            return self::SUCCESS;
        }

        $bar = $this->output->createProgressBar($pending->count());
        $done = 0;

        foreach ($pending->chunk((int) $this->option('batch')) as $chunk) {
            try {
                $data = $claude->enrich($chunk->pluck('word')->all());
            } catch (Throwable $e) {
                $this->newLine();
                $this->warn('Lote fallido: '.$e->getMessage());
                $bar->advance($chunk->count());

                continue;
            }

            foreach ($chunk as $word) {
                $d = $data[$word->word] ?? null;
                if ($d && filled($d['translation'] ?? null) && filled($d['example'] ?? null)) {
                    $word->update([
                        'translation' => mb_substr($d['translation'], 0, 255),
                        'example' => mb_substr($d['example'], 0, 255),
                        'example_es' => mb_substr($d['example_es'] ?? '', 0, 255),
                    ]);
                    $done++;
                }
                $bar->advance();
            }
        }

        $bar->finish();
        $this->newLine();
        $this->info("Listo: {$done} palabras enriquecidas. Vuelve a correrlo para reintentar las que fallaron.");

        return self::SUCCESS;
    }
}
