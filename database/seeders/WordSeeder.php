<?php

namespace Database\Seeders;

use App\Models\Word;
use Illuminate\Database\Seeder;

class WordSeeder extends Seeder
{
    public function run(): void
    {
        $rows = require database_path('data/starter_words.php');

        foreach ($rows as $i => [$en, $es, $example, $exampleEs]) {
            Word::updateOrCreate(
                ['word' => $en],
                [
                    'rank' => $i + 1,
                    'source' => 'starter',
                    'translation' => $es,
                    'example' => $example,
                    'example_es' => $exampleEs,
                ]
            );
        }
    }
}
