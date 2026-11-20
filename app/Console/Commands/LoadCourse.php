<?php

namespace App\Console\Commands;

use App\Models\Course;
use App\Models\Word;
use App\Support\CurrentCourse;
use Illuminate\Console\Command;

/**
 * Crea (o actualiza) un curso y carga sus palabras escritas de antemano, sin IA.
 *
 *   php artisan courses:load es-en            # la ficha de config/courses.php + database/content/courses/es-en/words/*.json
 *   php artisan courses:load es-en --dry-run  # solo cuenta y avisa de las filas mal escritas
 *
 * Solo acepta cursos apuntados en config/courses.php (lista fija). Se puede repetir: una palabra que ya
 * existe en ese curso se actualiza, nunca se duplica, y no toca las palabras de los demás cursos.
 */
class LoadCourse extends Command
{
    protected $signature = 'courses:load {code : Código del curso (config/courses.php)} {--path= : Carpeta de los .json} {--dry-run : No guarda nada}';

    protected $description = 'Crea un curso y carga sus palabras preparadas (sin IA)';

    /** Lo que trae cada palabra. Las cuatro primeras son obligatorias. */
    private const FIELDS = ['word', 'rank', 'translation', 'example', 'source', 'category', 'example_es', 'definition', 'gloss', 'emoji', 'definition_easy', 'phrase', 'sentence_long'];

    public function handle(CurrentCourse $current): int
    {
        $code = (string) $this->argument('code');
        $card = config("courses.{$code}.course");
        if (! is_array($card)) {
            $this->error("No hay ficha para «{$code}» en config/courses.php.");

            return self::FAILURE;
        }
        $dry = (bool) $this->option('dry-run');
        $dir = $this->option('path') ?: database_path("content/courses/{$code}/words");
        $rows = [];
        foreach (glob(rtrim($dir, '/').'/*.json') ?: [] as $file) {
            $data = json_decode((string) file_get_contents($file), true);
            if (! is_array($data)) {
                $this->warn(basename($file).': no es JSON válido, se salta.');

                continue;
            }
            array_push($rows, ...array_values($data));
        }

        [$good, $bad] = [[], 0];
        foreach ($rows as $row) {
            $why = self::problem($row);
            if ($why !== null) {
                $bad++;
                $this->warn('Fila saltada ('.(is_array($row) ? ($row['word'] ?? '?') : '?')."): {$why}");

                continue;
            }
            $good[mb_strtolower(trim($row['word']))] = $row;   // repetida en los archivos: vale la última
        }

        if ($dry) {
            $this->info("{$code}: ".count($good)." palabras listas, {$bad} con problemas. No se guardó nada (--dry-run).");

            return $bad ? self::FAILURE : self::SUCCESS;
        }

        $course = Course::updateOrCreate(['code' => $code], [
            'learn' => $card['learn'], 'from' => $card['from'], 'name' => $card['name'],
            'speech_locale' => $card['speech_locale'], 'active' => (bool) ($card['active'] ?? false),
        ]);
        [$created, $updated] = $current->run($course->id, function () use ($good) {
            $n = [0, 0];
            foreach ($good as $word => $row) {
                $values = ['source' => 'starter'] + array_intersect_key($row, array_flip(self::FIELDS));
                unset($values['word']);
                $w = Word::updateOrCreate(['word' => $word], $values);
                $n[$w->wasRecentlyCreated ? 0 : 1]++;
            }

            return $n;
        });
        $this->info("{$code} («{$course->name}», ".($course->active ? 'activo' : 'apagado')."): {$created} palabras nuevas, {$updated} actualizadas, {$bad} saltadas.");

        return self::SUCCESS;
    }

    /** null si la fila está bien; si no, qué le pasa. */
    public static function problem(mixed $row): ?string
    {
        if (! is_array($row)) {
            return 'no es una ficha';
        }
        foreach (['word', 'translation', 'example'] as $key) {
            if (! is_string($row[$key] ?? null) || trim($row[$key]) === '') {
                return "falta «{$key}»";
            }
        }
        if (! is_int($row['rank'] ?? null) || $row['rank'] < 1) {
            return 'falta «rank» (número de orden)';
        }
        if (substr_count($row['example'], '*') !== 2) {
            return 'el ejemplo debe marcar la palabra entre *asteriscos*';
        }

        return null;
    }
}
