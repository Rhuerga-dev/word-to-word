<?php

namespace App\Console\Commands;

use App\Models\Word;
use Illuminate\Console\Command;

/**
 * Importa la NGSL (New General Service List) u otra lista por frecuencia.
 * Acepta un CSV (la primera columna es la palabra) o un .txt con una palabra por línea.
 * El orden del archivo define el rank de frecuencia.
 *
 *   php artisan words:import storage/app/ngsl.csv
 */
class ImportWords extends Command
{
    protected $signature = 'words:import {file : Ruta al CSV o TXT} {--source=ngsl}';

    protected $description = 'Importa una lista de palabras por frecuencia (ej. NGSL)';

    public function handle(): int
    {
        $path = $this->argument('file');
        if (! is_file($path)) {
            $this->error("No encuentro el archivo: {$path}");

            return self::FAILURE;
        }

        $handle = fopen($path, 'r');
        $rank = Word::max('rank') ?? 0;
        $added = 0;
        $skipped = 0;

        while (($row = fgetcsv($handle)) !== false) {
            $word = strtolower(trim($row[0] ?? ''));
            $word = preg_replace('/^\xEF\xBB\xBF/', '', $word); // BOM
            if ($word === '' || in_array($word, ['lemma', 'word', 'headword'], true) || ! preg_match('/^[a-z][a-z\'\- ]*$/', $word)) {
                continue;
            }
            if (Word::where('word', $word)->exists()) {
                $skipped++;

                continue;
            }
            Word::create(['word' => $word, 'rank' => ++$rank, 'source' => $this->option('source')]);
            $added++;
        }
        fclose($handle);

        $this->info("Importadas {$added} palabras nuevas ({$skipped} ya existían).");
        $this->line('Ahora corre: php artisan words:enrich  (agrega traducción y ejemplo con IA)');

        return self::SUCCESS;
    }
}
