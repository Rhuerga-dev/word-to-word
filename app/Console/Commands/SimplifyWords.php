<?php

namespace App\Console\Commands;

use App\Models\Word;
use App\Services\ClaudeService;
use Illuminate\Console\Command;
use Throwable;

/**
 * Lo que necesita el ejercicio de Oído para cada palabra, escrito por la IA:
 * significado fácil (gloss, emoji, definición sencilla) y lo que se repite (frase corta y oración larga).
 * Primero las palabras que los alumnos ya aprendieron (son las que suenan en Oído).
 *
 *   php artisan words:simplify            (hasta 100 de las aprendidas)
 *   php artisan words:simplify --all --limit=500
 */
class SimplifyWords extends Command
{
    protected $signature = 'words:simplify {--limit=100} {--batch=25} {--all : También las que nadie estudia todavía}';

    protected $description = 'Significados muy fáciles y frases para repetir (ejercicio de Oído)';

    public function handle(ClaudeService $claude): int
    {
        if (! $claude->enabled()) {
            $this->warn('Sin ANTHROPIC_API_KEY: no se hace nada.');

            return self::SUCCESS;
        }
        $query = Word::whereNotNull('translation')->where(fn ($q) => $q->whereNull('gloss')->orWhereNull('phrase'));
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
                $w->update(self::fields($w, $m));
                $done++;
            }
        }
        $this->info("Palabras preparadas para Oído: {$done} de {$pending->count()}.");

        return self::SUCCESS;
    }

    /**
     * Valida lo que escribió la IA. El significado no puede decir la palabra (delataría la respuesta);
     * la frase y la oración sí tienen que contenerla. '' = ya se intentó (no se repite cada hora).
     *
     * @param  array{gloss: ?string, emoji: ?string, easy: ?string, phrase?: ?string, long?: ?string}  $m
     */
    public static function fields(Word $w, array $m): array
    {
        $root = mb_strtolower($w->word);
        $stem = mb_strlen($root) > 4 ? mb_substr($root, 0, -1) : $root; // rent/rents, deadline/deadlines, make/making
        $has = fn (?string $t) => $t !== null && preg_match('/\b'.preg_quote($stem, '/').'/u', mb_strtolower($t));
        $out = [];
        if ($w->gloss === null) {
            $out['gloss'] = $m['gloss'] && ! $has($m['gloss']) ? mb_substr($m['gloss'], 0, 60) : '';
            $out['emoji'] = $m['emoji'] ? mb_substr($m['emoji'], 0, 16) : null;
            $out['definition_easy'] = $m['easy'] && ! $has($m['easy']) ? mb_substr($m['easy'], 0, 255) : $w->definition_easy;
        }
        if ($w->phrase === null) {
            $out['phrase'] = ($m['phrase'] ?? null) && $has($m['phrase']) && str_word_count($m['phrase']) <= 6 ? mb_substr($m['phrase'], 0, 80) : '';
            $out['sentence_long'] = ($m['long'] ?? null) && $has($m['long']) ? mb_substr($m['long'], 0, 255) : null;
        }

        return $out;
    }
}
