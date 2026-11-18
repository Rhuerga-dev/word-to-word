<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** La mascota Brainy: crece con lo que el alumno aprende. Solo lee datos que ya existen. */
class PetTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create(['cefr_level' => 'B1']);
    }

    private function day(): string
    {
        return today(config('vocab.timezone'))->toDateString();
    }

    /** Aprende $n palabras; $stability = memoria FSRS de cada una (null = palabra de antes de FSRS). */
    private function learn(User $user, int $n, ?float $stability = 1.0, int $level = 0): void
    {
        for ($i = 0; $i < $n; $i++) {
            $w = Word::create(['word' => 'w'.uniqid(), 'rank' => 1, 'source' => 'ngsl', 'translation' => 't']);
            $uw = UserWord::create(['user_id' => $user->id, 'word_id' => $w->id, 'level' => $level, 'next_review' => $this->day(), 'introduced_at' => now()]);
            $uw->stability = $stability;
            $uw->save();
        }
    }

    private function passUnits(User $user, int $n): void
    {
        for ($i = 0; $i < $n; $i++) {
            DB::table('unit_progress')->insert(['user_id' => $user->id, 'unit' => "u{$i}", 'passed_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        }
    }

    public function test_the_pet_needs_login(): void
    {
        $this->getJson('/api/pet')->assertUnauthorized();
    }

    public function test_a_new_pet_is_a_spark_with_its_brain_off(): void
    {
        Sanctum::actingAs($this->user);

        $this->getJson('/api/pet')->assertOk()
            ->assertJsonPath('name', 'Brainy')->assertJsonPath('points', 0)
            ->assertJsonPath('stage.index', 0)->assertJsonPath('stage.key', 'spark')
            ->assertJsonPath('stage.next', 15)->assertJsonPath('stage.count', 5)
            ->assertJsonPath('regions.words.count', 0)->assertJsonPath('regions.words.target', 300)
            ->assertJsonPath('regions.memory.count', 0)->assertJsonPath('regions.path.count', 0)
            ->assertJsonPath('regions.habit.count', 0);
        $this->assertEquals(0, $this->getJson('/api/pet')->json('stage.progress'));
        $this->assertEquals(0, $this->getJson('/api/pet')->json('regions.links.level'));
    }

    public function test_it_grows_with_words_strong_words_units_and_streak(): void
    {
        Sanctum::actingAs($this->user);
        $this->learn($this->user, 10);                       // 10 palabras recién aprendidas
        $this->learn($this->user, 5, stability: 30.0);       // 5 que se recuerdan bien
        $this->passUnits($this->user, 2);
        $this->user->forceFill(['streak' => 4, 'last_study_day' => $this->day()])->save();

        $pet = $this->getJson('/api/pet')->assertOk();

        // 15 palabras + 5 × 2 (bien recordadas) + 2 × 8 (unidades) + 4 (racha) = 45 puntos
        $pet->assertJsonPath('points', 45)->assertJsonPath('stage.key', 'sprout')
            ->assertJsonPath('stage.from', 15)->assertJsonPath('stage.next', 60)
            ->assertJsonPath('regions.words.count', 15)->assertJsonPath('regions.memory.count', 5)
            ->assertJsonPath('regions.path.count', 2)->assertJsonPath('regions.habit.count', 4);
        $this->assertEqualsWithDelta(30 / 45, $pet->json('stage.progress'), 0.001);
        $this->assertEqualsWithDelta(0.05, $pet->json('regions.words.level'), 0.001);
        $this->assertEqualsWithDelta((0.05 + 5 / 150 + 2 / 12 + 4 / 30) / 4, $pet->json('regions.links.level'), 0.001);
    }

    public function test_words_from_before_fsrs_count_as_strong_by_their_level(): void
    {
        Sanctum::actingAs($this->user);
        config(['vocab.intervals' => [1, 3, 7, 14, 30, 60]]);
        $this->learn($this->user, 2, stability: null, level: 4);     // salto de 30 días ≥ 21: se recuerdan bien
        $this->learn($this->user, 3, stability: null, level: 3);     // salto de 14 días: todavía no
        $this->learn($this->user, 1, stability: 20.9);               // casi

        $this->getJson('/api/pet')->assertJsonPath('regions.words.count', 6)->assertJsonPath('regions.memory.count', 2);
    }

    public function test_the_streak_helps_only_up_to_a_limit_and_a_lost_streak_never_punishes(): void
    {
        Sanctum::actingAs($this->user);
        $this->learn($this->user, 20);
        $this->user->forceFill(['streak' => 200, 'last_study_day' => $this->day()])->save();
        $this->getJson('/api/pet')->assertJsonPath('points', 50)->assertJsonPath('regions.habit.count', 200);
        $this->assertEquals(1, $this->getJson('/api/pet')->json('regions.habit.level'));

        // Deja de estudiar muchos días: la racha se va, pero lo aprendido se queda. Nada baja de lo que ya sabe.
        $this->user->forceFill(['last_study_day' => today(config('vocab.timezone'))->subDays(40)->toDateString(), 'streak_freezes' => 0])->save();
        $pet = $this->getJson('/api/pet')->assertJsonPath('points', 20)->assertJsonPath('regions.words.count', 20)->assertJsonPath('stage.key', 'sprout');
        $this->assertArrayNotHasKey('mood', $pet->json(), 'la mascota no tiene estados tristes');
    }

    public function test_the_last_stage_is_complete_and_the_brain_never_goes_over_100(): void
    {
        Sanctum::actingAs($this->user);
        $this->learn($this->user, 320, stability: 40.0);
        $this->passUnits($this->user, 20);

        $pet = $this->getJson('/api/pet')->assertOk()->assertJsonPath('stage.key', 'wise')->assertJsonPath('stage.index', 4)->assertJsonPath('stage.next', null);
        $this->assertEquals(1, $pet->json('stage.progress'));
        foreach (['words', 'memory', 'path'] as $region) {
            $this->assertEquals(1, $pet->json("regions.{$region}.level"));
        }
    }

    public function test_each_user_sees_only_their_own_pet(): void
    {
        $other = User::factory()->create(['cefr_level' => 'B1']);
        $this->learn($other, 30, stability: 40.0);
        $this->passUnits($other, 3);
        Sanctum::actingAs($this->user);

        $this->getJson('/api/pet?user_id='.$other->id)->assertOk()->assertJsonPath('points', 0)->assertJsonPath('regions.words.count', 0);
    }

    public function test_reading_the_pet_only_writes_its_own_care_row(): void
    {
        Sanctum::actingAs($this->user);
        $this->learn($this->user, 3);
        $writes = function () {
            DB::flushQueryLog();
            DB::enableQueryLog();
            $this->getJson('/api/pet')->assertOk();

            return collect(DB::getQueryLog())->pluck('query')
                ->filter(fn ($q) => preg_match('/^\s*(insert|update|delete)/i', $q) && ! str_contains($q, 'cache') && ! str_contains($q, 'personal_access_tokens'))
                ->values();
        };

        // La primera vez nace su fila de cuidados (tabla pets); nada más se toca.
        $first = $writes();
        $this->assertNotEmpty($first);
        $first->each(fn ($q) => $this->assertStringContainsString('"pets"', $q));
        // Después, mirar a la mascota no escribe nada.
        $this->assertSame([], $writes()->all());
    }
}
