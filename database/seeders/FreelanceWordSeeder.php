<?php

namespace Database\Seeders;

use App\Models\Word;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Freelance vocabulary for client calls, placed at the front of the queue.
 *
 *   php artisan db:seed --class=FreelanceWordSeeder
 *
 * Existing words move back so these appear first as "new" words.
 * Running it again only updates translations and examples.
 */
class FreelanceWordSeeder extends Seeder
{
    public function run(): void
    {
        $rows = require database_path('data/freelance_words.php');
        $missing = array_values(array_filter($rows, fn ($r) => ! Word::where('word', $r[0])->exists()));

        DB::transaction(function () use ($rows, $missing) {
            if (count($missing) > 0) {
                Word::query()->increment('rank', count($missing));
            }

            $next = 1;
            foreach ($rows as [$en, $es, $example, $exampleEs]) {
                $word = Word::firstWhere('word', $en);
                $data = ['translation' => $es, 'example' => $example, 'example_es' => $exampleEs];

                if ($word) {
                    $word->update($data);
                } else {
                    Word::create($data + ['word' => $en, 'rank' => $next++, 'source' => 'freelance']);
                }
            }
        });

        $this->command?->info(count($missing).' freelance words added at the front of the queue.');
    }
}
