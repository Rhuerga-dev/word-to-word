<?php

namespace App\Console\Commands;

use App\Models\Word;
use Illuminate\Console\Command;

/**
 * Carga contenido de palabras escrito de antemano (sin llamar a la IA en vivo) desde database/content/words/*.json.
 * Formato: {"word": {"definition": "...", "definition_easy": "...", "sentence_long": "..."}, ...}
 * Solo rellena campos VACÍOS (nunca pisa lo que ya hay) y aplica las mismas reglas de calidad que la IA:
 * la definición no puede contener la palabra; la frase larga sí tiene que contenerla.
 *
 *   php artisan words:content            (todos los archivos)
 *   php artisan words:content --dry-run  (solo cuenta, no guarda)
 */
class ImportWordContent extends Command
{
    protected $signature = 'words:content {--path= : Carpeta o archivo .json} {--dry-run : Solo contar, no guardar}';

    protected $description = 'Rellena definiciones y frases de palabras con contenido preparado (sin IA)';

    public function handle(): int
    {
        $path = $this->option('path') ?: database_path('content/words');
        $files = is_dir($path) ? glob(rtrim($path, '/').'/*.json') : [$path];
        $stats = ['definition' => 0, 'definition_easy' => 0, 'sentence_long' => 0, 'rejected' => 0, 'unknown' => 0];

        foreach ($files as $file) {
            $data = json_decode((string) @file_get_contents($file), true);
            if (! is_array($data)) {
                $this->warn('Archivo sin JSON válido: '.basename($file));

                continue;
            }
            foreach ($data as $word => $m) {
                $w = is_array($m) ? Word::whereRaw('lower(word) = ?', [mb_strtolower((string) $word)])->first() : null;
                if (! $w) {
                    $stats['unknown']++;

                    continue;
                }
                $fields = self::fields($w, $m, $stats);
                if ($fields && ! $this->option('dry-run')) {
                    $w->update($fields);
                }
            }
        }

        $this->info(sprintf(
            '%sDefiniciones: %d · fáciles: %d · frases largas: %d · rechazadas: %d · palabras que no existen: %d',
            $this->option('dry-run') ? '[prueba] ' : '',
            $stats['definition'], $stats['definition_easy'], $stats['sentence_long'], $stats['rejected'], $stats['unknown'],
        ));

        return self::SUCCESS;
    }

    /** Los campos que se pueden rellenar para [$w] con [$m] (solo los vacíos y que pasan las reglas). */
    public static function fields(Word $w, array $m, array &$stats = []): array
    {
        $root = mb_strtolower($w->word);
        $stem = mb_strlen($root) > 4 ? mb_substr($root, 0, -1) : $root;
        $has = fn (string $t, string $needle) => (bool) preg_match('/\b'.preg_quote($needle, '/').'/u', mb_strtolower($t));
        $text = fn ($v) => is_string($v) && trim($v) !== '' ? trim(preg_replace('/\s+/', ' ', $v)) : null;
        $out = [];

        $check = function (string $field, ?string $value, bool $ok, int $max) use ($w, &$out, &$stats) {
            if ($w->{$field} !== null || $value === null) {
                return;
            }
            if ($ok && mb_strlen($value) <= $max) {
                $out[$field] = $value;
                $stats[$field] = ($stats[$field] ?? 0) + 1;
            } else {
                $stats['rejected'] = ($stats['rejected'] ?? 0) + 1;
            }
        };

        $def = $text($m['definition'] ?? null);
        $check('definition', $def, $def !== null && ! $has($def, $root) && str_word_count($def) <= 14, 255);
        $easy = $text($m['definition_easy'] ?? null);
        $check('definition_easy', $easy, $easy !== null && ! $has($easy, $stem) && str_word_count($easy) <= 12, 255);
        $long = $text($m['sentence_long'] ?? null);
        $check('sentence_long', $long, $long !== null && $has($long, $stem), 255);

        return $out;
    }
}
