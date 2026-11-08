<?php

namespace Database\Seeders;

use App\Models\Word;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Familias de palabras (cuerpo, comida, frutas…).
 *
 *   php artisan db:seed --class=FamilyWordSeeder
 *
 * Si la palabra ya existe solo se le asigna la familia (y se completa la
 * traducción o el ejemplo si faltaban). Las que no existen se agregan al
 * final con source "family", así no cambian los niveles.
 * Se puede correr las veces que quieras.
 */
class FamilyWordSeeder extends Seeder
{
    public function run(): void
    {
        $families = require database_path('data/family_words.php');
        $added = $tagged = 0;

        DB::transaction(function () use ($families, &$added, &$tagged) {
            $rank = (int) Word::max('rank');
            foreach ($families as $family => $rows) {
                foreach ($rows as [$en, $es, $example, $exampleEs]) {
                    $word = Word::firstWhere('word', $en);
                    if ($word) {
                        $word->category = $family;
                        $word->translation = $word->translation ?: $es;
                        if (! $word->example) {
                            $word->example = $example;
                            $word->example_es = $exampleEs;
                        }
                        $word->save();
                        $tagged++;
                    } else {
                        Word::create([
                            'word' => $en, 'rank' => ++$rank, 'source' => 'family', 'category' => $family,
                            'translation' => $es, 'example' => $example, 'example_es' => $exampleEs,
                        ]);
                        $added++;
                    }
                }
            }
        });

        $this->command?->info("Familias listas: $added palabras nuevas y $tagged existentes agrupadas.");
    }
}
