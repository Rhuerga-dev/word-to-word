<?php

namespace Tests\Feature;

use App\Console\Commands\MetricsSnapshot;
use App\Services\DemoService;
use App\Models\User;
use App\Models\Word;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Capa 2 del panel: aciertos por habilidad, dónde se atascan y racha. La demo no cuenta. */
class MetricsLearningTest extends TestCase
{
    use RefreshDatabase;

    private function learning(): array
    {
        return (new MetricsSnapshot)->compute(CarbonImmutable::today(config('vocab.timezone')))['learning'];
    }

    public function test_resume_el_aprendizaje_y_deja_fuera_la_demo(): void
    {
        $today = today(config('vocab.timezone'))->toDateString();
        $u = User::factory()->create(['streak' => 5, 'streak_freezes' => 1]);
        User::factory()->create(['streak' => 0, 'streak_freezes' => 0]);
        $demo = User::factory()->create(['email' => 'demo-x@'.DemoService::DOMAIN, 'streak' => 99, 'streak_freezes' => 1]);

        $apple = Word::create(['word' => 'apple', 'rank' => 1, 'translation' => 'manzana']);
        $banana = Word::create(['word' => 'banana', 'rank' => 2, 'translation' => 'plátano']);
        DB::table('user_words')->insert([
            ['user_id' => $u->id, 'word_id' => $apple->id, 'reviews' => 10, 'fails' => 2],
            ['user_id' => $u->id, 'word_id' => $banana->id, 'reviews' => 5, 'fails' => 4],
            // La demo con muchos fallos: no debe aparecer ni mover los aciertos.
            ['user_id' => $demo->id, 'word_id' => $apple->id, 'reviews' => 50, 'fails' => 50],
        ]);

        DB::table('listening_days')->insert([
            ['user_id' => $u->id, 'day' => $today, 'ear_ok' => 8, 'ear_fail' => 2, 'repeats' => 3],
            ['user_id' => $demo->id, 'day' => $today, 'ear_ok' => 0, 'ear_fail' => 100, 'repeats' => 0],
        ]);

        DB::table('speaking_sessions')->insert(['user_id' => $u->id, 'day' => $today, 'words' => 50]);
        $rows = [];
        for ($i = 0; $i < 5; $i++) {
            $rows[] = ['user_id' => $u->id, 'said' => 'go', 'correct' => 'went', 'next_review' => $today, 'created_at' => now(), 'updated_at' => now()];
        }
        DB::table('speaking_mistakes')->insert($rows);

        $l = $this->learning();

        $this->assertSame(80, $l['ear_accuracy']['percent']);      // 8 / 10
        $this->assertSame(3, $l['ear_accuracy']['repeats']);
        $this->assertSame(60, $l['vocab_accuracy']['percent']);    // (15-6)/15
        $this->assertSame(90, $l['speaking_clean']['percent']);    // (50-5)/50
        $this->assertSame(5, $l['speaking_clean']['mistakes']);

        // Dónde se atascan: banana (4 fallos) antes que apple (2); la demo no está.
        $this->assertSame([
            ['word' => 'banana', 'fails' => 4],
            ['word' => 'apple', 'fails' => 2],
        ], $l['top_failed_words']);

        $this->assertSame(5.0, $l['avg_streak']);                  // solo el usuario real con racha
        $this->assertSame(1, $l['users_with_freeze']);             // la demo no cuenta
    }

    public function test_sin_datos_no_rompe_y_devuelve_nulos(): void
    {
        $l = $this->learning();
        $this->assertNull($l['ear_accuracy']['percent']);
        $this->assertNull($l['vocab_accuracy']['percent']);
        $this->assertSame([], $l['top_failed_words']);
        $this->assertSame(0, $l['users_with_freeze']);
    }
}
