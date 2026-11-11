<?php

namespace App\Console\Commands;

use App\Models\Word;
use App\Services\ClaudeService;
use Illuminate\Console\Command;
use Throwable;

/**
 * Significados fáciles (gloss, emoji, definición sencilla) para el ejercicio de Oído.
 * Primero las palabras que los alumnos ya aprendieron (son las que suenan en Oído).
 *
 *   php artisan words:simplify            (hasta 100 de las aprendidas)
 *   php artisan words:simplify --all --limit=500
 */
class SimplifyWords extends Command
{
    protected $signature = 'words:simplify {--limit=100} {--batch=25} {--all : También las que nadie estudia todavía}';

    protected $description = 'Agrega significados muy fáciles en inglés (para reconocer palabras de oído)';

    public function handle(ClaudeService $claude): int
    {
        if (! $claude->enabled()) {
            $this->warn('Sin ANTHROPIC_API_KEY: no se hace nada.');

            return self::SUCCESS;
        }
        $query = Word::whereNull('gloss')->whereNotNull('translation');
        if (! $this->option('all')) {
            $query->whereIn('id', fn ($q) => $q->select('word_id')->from('user_words')->whereNotNull('introduced_at'));
        }
        $pending = $query->orderBy('rank')->limit((int) $this->option('limit'))->get();
        $done = 0;
        foreach ($pending->chunk((int) $this->option('batch')) as $chunk) {
            try {
                $out = $claude->simplify($chunk->pluck('word')->all());
            } catch (Throwable $e) {
                $this->warn('Lote fallido: '.$e->getMessage());

                continue;
            }
            foreach ($chunk as $w) {
                $m = $out[$w->word] ?? null;
                if (! $m) {
                    continue;
                }
                // Si menciona la palabra, delataría la respuesta: se descarta ese campo.
                $leaks = fn (?string $t) => $t !== null && preg_match('/\b'.preg_quote(mb_strtolower($w->word), '/').'/u', mb_strtolower($t));
                $w->update([
                    // '' = ya se intentó (no se repite cada hora).
                    'gloss' => $m['gloss'] && ! $leaks($m['gloss']) ? mb_substr($m['gloss'], 0, 60) : '',
                    'emoji' => $m['emoji'] ? mb_substr($m['emoji'], 0, 16) : null,
                    'definition_easy' => $m['easy'] && ! $leaks($m['easy']) ? mb_substr($m['easy'], 0, 255) : null,
                ]);
                $done++;
            }
        }
        $this->info("Significados fáciles: {$done} de {$pending->count()}.");

        return self::SUCCESS;
    }
}
