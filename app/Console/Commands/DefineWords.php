<?php

namespace App\Console\Commands;

use App\Models\Word;
use App\Services\ClaudeService;
use Illuminate\Console\Command;
use Throwable;

/**
 * Escribe la definición en inglés de las palabras que los alumnos ya estudian (para las fichas sin español).
 *
 *   php artisan words:define              (hasta 200, empezando por las que ya se repasan)
 *   php artisan words:define --all --limit=1000
 */
class DefineWords extends Command
{
    protected $signature = 'words:define {--limit=200} {--batch=40} {--all : También las que nadie estudia todavía}';

    protected $description = 'Agrega definiciones sencillas en inglés con la API de Claude';

    public function handle(ClaudeService $claude): int
    {
        if (! $claude->enabled()) {
            $this->error('Falta ANTHROPIC_API_KEY en .env');

            return self::FAILURE;
        }

        $query = Word::whereNull('definition')->whereNotNull('translation');
        if (! $this->option('all')) {
            $query->whereIn('id', fn ($q) => $q->select('word_id')->from('user_words')->whereNotNull('introduced_at'));
        }
        $pending = $query->orderBy('rank')->limit((int) $this->option('limit'))->get();
        $done = 0;

        foreach ($pending->chunk((int) $this->option('batch')) as $chunk) {
            try {
                $defs = $claude->define($chunk->pluck('word')->all());
            } catch (Throwable $e) {
                $this->warn('Lote fallido: '.$e->getMessage());

                continue;
            }
            foreach ($chunk as $word) {
                $def = $defs[$word->word] ?? null;
                // Una definición que contiene la palabra delataría la respuesta.
                if ($def && ! preg_match('/\b'.preg_quote(mb_strtolower($word->word), '/').'/u', mb_strtolower($def))) {
                    $word->update(['definition' => mb_substr($def, 0, 255)]);
                    $done++;
                }
            }
        }
        $this->info("Definiciones nuevas: {$done} de {$pending->count()}.");

        return self::SUCCESS;
    }
}
