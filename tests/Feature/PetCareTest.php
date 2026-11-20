<?php

namespace Tests\Feature;

use App\Models\SpeakingMistake;
use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\XpService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Los cuidados de Brainy (comida, ánimo, limpieza, salud): cuidarla = estudiar.
 * Las barras bajan con el reloj aunque la app esté cerrada, de noche duerme, y nunca muere.
 */
class PetCareTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->at('2026-11-18 12:00');                  // un mediodía cualquiera, hora del alumno
        $this->user = User::factory()->create(['cefr_level' => 'B1']);
        Sanctum::actingAs($this->user);
    }

    private function at(string $local): void
    {
        $this->travelTo(CarbonImmutable::parse($local, config('vocab.timezone')));
    }

    private function care(): array
    {
        return $this->getJson('/api/pet')->assertOk()->json('care');
    }

    private function hearts(): array
    {
        return array_map(fn ($n) => $n['hearts'], $this->care()['needs']);
    }

    private function word(): Word
    {
        return Word::create(['word' => 'w'.uniqid(), 'rank' => 1, 'source' => 'ngsl', 'translation' => 't']);
    }

    /** $n palabras ya aprendidas cuyo repaso tocaba hace $daysAgo días (0 = hoy). */
    private function due(int $n, int $daysAgo = 0): void
    {
        $day = today(config('vocab.timezone'))->subDays($daysAgo)->toDateString();
        for ($i = 0; $i < $n; $i++) {
            UserWord::create(['user_id' => $this->user->id, 'word_id' => $this->word()->id, 'level' => 1, 'next_review' => $day, 'introduced_at' => now()]);
        }
    }

    private function did(string $source, int $times = 1): void
    {
        for ($i = 0; $i < $times; $i++) {
            app(XpService::class)->add($this->user, $source);
        }
    }

    public function test_a_new_pet_is_born_half_fed_clean_and_healthy(): void
    {
        $care = $this->care();

        $this->assertSame(['food' => 2, 'joy' => 2, 'clean' => 4, 'health' => 4], $this->hearts());
        $this->assertSame(4, $care['needs']['food']['max']);
        $this->assertSame('ok', $care['mood']);
        $this->assertFalse($care['asleep']);
        $this->assertFalse($care['sick']);
        $this->assertFalse($care['hibernating']);
        $this->assertNull($care['leaning']);
        $this->assertSame('spark', $care['history'][0]['stage']);
    }

    public function test_hunger_and_boredom_grow_with_time_even_with_the_app_closed(): void
    {
        $this->care();                                   // nace a las 12:00 con 2 corazones
        $this->at('2026-11-18 18:00');                   // 6 h después: un corazón de comida menos

        $this->assertSame(1, $this->hearts()['food']);
        $this->assertSame(2, $this->hearts()['joy']);    // el ánimo baja más despacio (8 h)
        $this->assertSame('hungry', $this->care()['mood']);

        $this->at('2026-11-19 21:00');                   // al día siguiente: vacía
        $this->assertSame(0, $this->hearts()['food']);
        $this->assertSame(0, $this->hearts()['joy']);
    }

    public function test_it_says_when_it_will_be_hungry_or_want_to_play(): void
    {
        $alerts = collect($this->care()['alerts'])->pluck('at', 'kind');
        $local = fn (string $kind) => CarbonImmutable::parse($alerts[$kind])->setTimezone(config('vocab.timezone'))->format('Y-m-d H:i');

        // Nace a las 12:00 con 2 corazones: 6 h despierta por corazón de comida, 8 h por uno de ánimo.
        $this->assertSame('2026-11-18 18:00', $local('hungry'));
        $this->assertSame('2026-11-18 20:00', $local('bored'));

        // Y es verdad: un minuto antes aún no tiene hambre; a esa hora, sí.
        $this->at('2026-11-18 17:59');
        $this->assertSame(2, $this->hearts()['food']);
        $this->at('2026-11-18 18:00');
        $this->assertSame(1, $this->hearts()['food']);
        // Lo que ya pasó no se vuelve a avisar.
        $this->assertSame(['bored'], collect($this->care()['alerts'])->pluck('kind')->all());
    }

    public function test_the_alerts_never_fall_at_night_and_stop_when_it_is_sick_or_hibernating(): void
    {
        $this->did('learn', 2);                          // comida a 4 corazones → 18 h despierta hasta quedarse en 1
        $this->at('2026-11-18 20:00');
        $this->did('ear', 4);                            // ánimo: 1 (ya bajó uno) + 1 = 2 → 8 h despierta
        $alerts = collect($this->care()['alerts'])->pluck('at', 'kind');
        $local = fn (string $kind) => CarbonImmutable::parse($alerts[$kind])->setTimezone(config('vocab.timezone'));

        // Ánimo: 2 h esta noche (hasta las 22:00) + 6 h mañana desde las 07:00 → 13:00.
        $this->assertSame('2026-11-19 13:00', $local('bored')->format('Y-m-d H:i'));
        foreach ($alerts->keys() as $kind) {
            $this->assertTrue($local($kind)->hour >= 7 && $local($kind)->hour < 22, "$kind cae de noche");
        }

        $this->at('2026-11-26 12:00');                   // más de 5 días sin cuidarla: hiberna
        $this->assertTrue($this->care()['hibernating']);
        $this->assertSame([], $this->care()['alerts']);
    }

    public function test_at_night_it_sleeps_and_nothing_goes_down(): void
    {
        $this->at('2026-11-18 21:30');
        $this->care();                                   // 2 corazones a las 21:30
        $this->at('2026-11-19 03:00');

        $this->assertSame('asleep', $this->care()['mood']);
        $this->assertTrue($this->care()['asleep']);
        $this->at('2026-11-19 07:00');                   // 9,5 h de reloj, solo 0,5 h despierta
        $this->assertSame(2, $this->hearts()['food']);
        $this->assertFalse($this->care()['asleep']);
    }

    public function test_learning_a_word_feeds_it_and_a_review_is_a_snack(): void
    {
        $this->care();
        $word = $this->word();

        $this->postJson("/api/words/{$word->id}/learn")->assertSuccessful();
        $this->assertSame(3, $this->hearts()['food']);

        $this->did('review', 4);                         // 4 meriendas = un corazón
        $this->assertSame(4, $this->hearts()['food']);
        $this->did('learn', 10);                         // nunca pasa del máximo
        $this->assertSame(4, $this->hearts()['food']);
    }

    public function test_playing_ear_cheers_it_up_even_with_a_slow_answer(): void
    {
        $this->care();
        $this->due(1, -5);                               // una palabra aprendida (sin repaso pendiente)
        $word = UserWord::where('user_id', $this->user->id)->first()->word_id;

        $this->postJson("/api/words/{$word}/ear", ['ok' => true, 'ms' => 9000])->assertOk()->assertJsonPath('xp_gained', 0);

        $this->assertSame(3, $this->hearts()['joy']);    // 2 + 0,25 → tercer corazón empezado
    }

    public function test_pending_reviews_and_mistakes_are_its_mess(): void
    {
        $this->assertSame(4, $this->hearts()['clean']);
        $this->due(4);
        SpeakingMistake::create(['user_id' => $this->user->id, 'said' => 'a', 'correct' => 'b', 'next_review' => today(config('vocab.timezone'))->toDateString()]);
        $this->assertSame(3, $this->hearts()['clean']);  // 5 pendientes
        $this->assertSame(5, $this->care()['mess']);

        $this->due(11);
        $this->assertSame(1, $this->hearts()['clean']);  // 16
        $this->due(15);
        $this->assertSame(0, $this->hearts()['clean']);  // 31
        $this->did('learn', 4);
        $this->assertSame('messy', $this->care()['mood']);

        // Hacer los repasos limpia.
        UserWord::where('user_id', $this->user->id)->update(['next_review' => '2027-01-01']);
        $this->assertSame(3, $this->hearts()['clean']);  // queda el error
    }

    public function test_a_day_of_too_much_mess_makes_it_sick_and_the_sound_workshop_is_the_medicine(): void
    {
        $this->due(31, daysAgo: 1);                      // tocaban ayer: el día de plazo acaba esta noche
        $this->did('learn', 4);
        $this->assertFalse($this->care()['sick']);

        $this->at('2026-11-20 09:00');                   // pasó un día entero con el desorden a tope
        $this->did('learn', 4);                          // está comida: la causa es el desorden
        $care = $this->care();
        $this->assertTrue($care['sick']);
        $this->assertSame('sick', $care['mood']);
        $this->assertLessThan(4, $care['needs']['health']['hearts']);
        $this->assertGreaterThanOrEqual(1, $care['needs']['health']['hearts']);

        app(XpService::class)->petCare($this->user, 'workshop');
        $this->assertFalse($this->care()['sick']);
        $this->assertSame(4, $this->hearts()['health']);
    }

    public function test_it_is_born_healthy_even_with_an_old_backlog(): void
    {
        $this->due(60, daysAgo: 20);                     // alumno con muchos repasos atrasados de antes
        $care = $this->care();
        $this->assertSame(0, $care['needs']['clean']['hearts']);
        $this->assertFalse($care['sick'], 'no nace enferma');

        $this->at('2026-11-19 11:00');                   // aún no ha pasado un día entero desde que nació
        $this->did('learn', 4);
        $this->assertFalse($this->care()['sick']);
        $this->at('2026-11-19 13:00');
        $this->did('learn', 4);
        $this->assertTrue($this->care()['sick']);
    }

    public function test_a_day_starving_makes_it_sick_and_feeding_it_heals(): void
    {
        $this->care();                                   // 2 corazones: a cero tras 12 h despierta
        $this->did('session');                           // la cuida (no hiberna) pero no come
        $this->at('2026-11-19 20:00');                   // 23 h despierta: 11 con hambre a cero
        $this->did('session');
        $this->assertFalse($this->care()['sick']);

        $this->at('2026-11-20 13:00');                   // 6 h más despierta
        $this->assertTrue($this->care()['sick']);

        $this->did('learn');
        $this->assertFalse($this->care()['sick']);
    }

    public function test_it_never_dies_it_hibernates_and_wakes_up_when_you_come_back(): void
    {
        $this->due(40, daysAgo: 1);
        $this->care();
        $this->at('2026-12-25 12:00');                   // más de un mes sin aparecer

        $care = $this->care();
        $this->assertTrue($care['hibernating']);
        $this->assertSame('hibernating', $care['mood']);
        $this->assertFalse($care['sick'], 'hibernando no enferma ni empeora');

        $this->did('review');                            // vuelves y haces un repaso
        $care = $this->care();
        $this->assertFalse($care['hibernating']);
        $this->assertFalse($care['sick']);
        $this->assertSame(3, $care['needs']['food']['hearts']);   // despierta con 2 + la merienda
        $this->assertSame(2, $care['needs']['joy']['hearts']);
    }

    public function test_the_stage_never_goes_down_and_its_history_is_kept(): void
    {
        $this->due(20, -5);                              // 20 palabras → 20 puntos → «Brote»
        $this->getJson('/api/pet')->assertJsonPath('stage.key', 'sprout');

        UserWord::where('user_id', $this->user->id)->delete();
        $pet = $this->getJson('/api/pet')->assertJsonPath('points', 0)->assertJsonPath('stage.key', 'sprout')->assertJsonPath('stage.index', 1);
        $this->assertEquals(0, $pet->json('stage.progress'));
        $this->assertSame(['sprout'], array_column($pet->json('care.history'), 'stage'));
        $this->assertSame('2026-11-18', $pet->json('care.history.0.at'));
    }

    public function test_its_adult_form_depends_on_what_you_practice_most(): void
    {
        $this->assertNull($this->care()['leaning']);     // todavía no se sabe
        $this->did('speak', 2);                          // hablar: 100 puntos por vez
        app(XpService::class)->add($this->user, 'speak', 100);
        $this->assertSame('talker', $this->care()['leaning']);
        $this->assertNull($this->care()['form']);        // la forma solo se fija de adulta

        DB::table('pets')->update(['vocab_points' => 100, 'ear_points' => 100, 'talk_points' => 100]);
        $this->assertSame('balanced', $this->care()['leaning']);

        DB::table('pets')->update(['ear_points' => 900]);
        config(['pet.stages' => ['spark' => 0, 'wise' => 1]]);
        $this->due(3, -5);                               // llega a la última etapa: se fija «orejona»
        $this->assertSame('listener', $this->care()['form']);
        DB::table('pets')->update(['talk_points' => 9000]);
        $this->assertSame('listener', $this->care()['form'], 'la forma adulta ya no cambia');
    }

    public function test_care_days_count_each_day_once(): void
    {
        $this->did('review', 3);
        $this->assertSame(1, $this->care()['days']);
        $this->at('2026-11-19 10:00');
        $this->did('ear');
        $this->assertSame(2, $this->care()['days']);
    }

    public function test_the_care_buttons_say_which_exercise_to_do_and_give_nothing_for_free(): void
    {
        $this->care();
        $this->postJson('/api/pet/clean')->assertOk()->assertJsonPath('action', 'clean')->assertJsonPath('go', null);
        $this->postJson('/api/pet/play')->assertOk()->assertJsonPath('go', 'sound');
        $this->postJson('/api/pet/medicine')->assertOk()->assertJsonPath('go', 'sound');

        $this->due(2);
        $this->postJson('/api/pet/clean')->assertJsonPath('go', 'reviews');
        $this->postJson('/api/pet/play')->assertJsonPath('go', 'ear');
        $feed = $this->postJson('/api/pet/feed')->assertOk();
        $this->assertContains($feed->json('go'), ['new', 'reviews']);

        // Pulsar botones no da corazones: los da hacer el ejercicio.
        $this->assertSame(2, $feed->json('pet.care.needs.food.hearts'));
        $this->assertSame(2, $feed->json('pet.care.needs.joy.hearts'));
    }

    public function test_only_the_four_fixed_actions_exist_and_they_need_login(): void
    {
        $this->postJson('/api/pet/kill')->assertNotFound();
        $this->postJson('/api/pet/feed;rm')->assertNotFound();
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/pet/feed')->assertUnauthorized();
    }

    public function test_each_user_has_their_own_care(): void
    {
        $other = User::factory()->create(['cefr_level' => 'B1']);
        app(XpService::class)->add($other, 'learn');
        app(XpService::class)->add($other, 'learn');

        $this->assertSame(2, $this->hearts()['food']);
        $this->assertSame(4.0, (float) DB::table('pets')->where('user_id', $other->id)->value('food'));
    }

    public function test_resetting_progress_or_deleting_the_account_erases_the_pet(): void
    {
        $this->did('learn');
        $this->assertSame(1, DB::table('pets')->count());
        $this->user->forceFill(['password' => bcrypt('clave-segura-123')])->save();

        $this->postJson('/api/reset', ['password' => 'clave-segura-123'])->assertNoContent();
        $this->assertSame(0, DB::table('pets')->count());

        $this->care();
        $this->user->delete();
        $this->assertSame(0, DB::table('pets')->count());
    }

    public function test_if_the_care_fails_points_and_the_pet_still_work(): void
    {
        Schema::drop('pets');

        $this->assertSame(5, app(XpService::class)->add($this->user, 'learn'));
        $pet = $this->getJson('/api/pet')->assertOk()->assertJsonPath('stage.key', 'spark');
        $this->assertArrayNotHasKey('care', $pet->json());
    }
}
