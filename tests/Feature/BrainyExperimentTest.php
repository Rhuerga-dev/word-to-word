<?php

namespace Tests\Feature;

use App\Console\Commands\MetricsSnapshot;
use App\Models\User;
use App\Models\Word;
use App\Services\BrainyExperiment;
use App\Services\DemoService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Experimento A/B del Modo Brainy: grupos estables, lo que informa la app y el informe que compara los grupos. */
class BrainyExperimentTest extends TestCase
{
    use RefreshDatabase;

    private function on(?string $start = null, array $exclude = [], int $min = 20): void
    {
        config(['experiments.brainy' => ['enabled' => true, 'start' => $start ?? $this->day(-30), 'exclude_ids' => $exclude, 'min_users' => $min]]);
    }

    private function day(int $offset = 0): string
    {
        return CarbonImmutable::today(config('vocab.timezone'))->addDays($offset)->toDateString();
    }

    /** Crea alumnos hasta que salga uno del grupo pedido (el grupo depende solo del id). */
    private function userIn(string $group): User
    {
        for ($i = 0; $i < 50; $i++) {
            $u = User::factory()->create();
            if (BrainyExperiment::groupOf($u->id) === $group) {
                return $u;
            }
        }
        $this->fail('No salió ningún alumno del grupo '.$group);
    }

    private function exp(): BrainyExperiment
    {
        return app(BrainyExperiment::class);
    }

    // ---------- Grupos ----------

    public function test_apagado_todo_queda_como_siempre(): void
    {
        config(['experiments.brainy.enabled' => false, 'experiments.brainy.start' => $this->day(-5)]);
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->getJson('/api/me')->assertOk()->assertJsonPath('brainy_default', null);
        $this->postJson('/api/experiments/brainy', ['mode' => true])->assertOk()->assertJsonPath('counted', false);
        $this->assertSame(0, DB::table('experiment_participants')->count());
    }

    public function test_sin_fecha_o_antes_de_la_fecha_de_inicio_no_esta_en_marcha(): void
    {
        foreach ([null, '', 'mañana', '2026-13-45', $this->day(1)] as $start) {
            config(['experiments.brainy' => ['enabled' => true, 'start' => $start, 'exclude_ids' => [], 'min_users' => 20]]);
            $this->assertFalse($this->exp()->active(), 'inicio: '.var_export($start, true));
            $this->assertNull($this->exp()->default(User::factory()->create()));
        }
        $this->on($this->day());
        $this->assertTrue($this->exp()->active(), 'el día de inicio ya cuenta');
    }

    public function test_el_grupo_es_estable_y_sale_de_la_formula(): void
    {
        $this->on();
        $groups = [];
        foreach (User::factory()->count(40)->create() as $u) {
            $expected = crc32('brainy-ab:'.$u->id) % 2 === 1 ? 'brainy' : 'control';
            $this->assertSame($expected, $this->exp()->group($u));
            $this->assertSame($expected, $this->exp()->group($u->fresh()), 'siempre el mismo');
            $groups[$expected] = ($groups[$expected] ?? 0) + 1;
        }
        $this->assertGreaterThanOrEqual(10, $groups['brainy']);     // reparto razonable entre los dos
        $this->assertGreaterThanOrEqual(10, $groups['control']);
    }

    public function test_me_dice_el_modo_por_defecto_de_cada_grupo(): void
    {
        $this->on();
        Sanctum::actingAs($this->userIn('brainy'));
        $this->getJson('/api/me')->assertOk()->assertJsonPath('brainy_default', true);
        Sanctum::actingAs($this->userIn('control'));
        $this->getJson('/api/me')->assertOk()->assertJsonPath('brainy_default', false);
    }

    public function test_la_demo_y_las_cuentas_excluidas_no_entran(): void
    {
        $mine = User::factory()->create();
        $demo = User::factory()->create(['email' => 'demo-x@'.DemoService::DOMAIN]);
        $this->on(exclude: [$mine->id]);

        foreach ([$mine, $demo] as $u) {
            Sanctum::actingAs($u);
            $this->getJson('/api/me')->assertOk()->assertJsonPath('brainy_default', null);
            $this->postJson('/api/experiments/brainy', ['mode' => true, 'changed' => true, 'opened' => true])->assertOk()->assertJsonPath('counted', false);
            $this->postJson('/api/pet/feed')->assertOk();
        }
        $this->assertSame(0, DB::table('experiment_participants')->count());
    }

    // ---------- Lo que informa la app ----------

    public function test_hace_falta_sesion_y_solo_existe_el_experimento_de_la_lista(): void
    {
        $this->on();
        $this->postJson('/api/experiments/brainy', ['mode' => true])->assertUnauthorized();
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/experiments/otro', ['mode' => true])->assertNotFound();
        foreach ([[], ['mode' => 'quizá'], ['mode' => true, 'changed' => 'x'], ['mode' => true, 'opened' => [1]]] as $bad) {
            $this->postJson('/api/experiments/brainy', $bad)->assertStatus(422);
        }
        $this->assertSame(0, DB::table('experiment_participants')->count());
    }

    public function test_guarda_el_grupo_el_modo_real_si_lo_cambio_y_cuando(): void
    {
        $this->on();
        $user = $this->userIn('brainy');
        $other = $this->userIn('control');
        Sanctum::actingAs($user);

        // El cliente intenta elegir grupo y dueño: se ignoran.
        $this->postJson('/api/experiments/brainy', ['mode' => true, 'changed' => false, 'group' => 'control', 'user_id' => $other->id])
            ->assertOk()->assertJsonPath('counted', true);
        $row = DB::table('experiment_participants')->sole();
        $this->assertSame([$user->id, 'brainy', 'brainy', 1, 0, null, $this->day()],
            [$row->user_id, $row->experiment, $row->group, (int) $row->mode, (int) $row->changed, $row->changed_at, substr($row->entered_day, 0, 10)]);

        // Lo apaga a mano: queda apuntado, con su momento.
        $this->postJson('/api/experiments/brainy', ['mode' => false, 'changed' => true])->assertOk();
        $row = DB::table('experiment_participants')->sole();
        $this->assertSame([0, 1], [(int) $row->mode, (int) $row->changed]);
        $this->assertNotNull($row->changed_at);

        // Aunque la app luego diga «no lo cambié» (reinstalación), el servidor recuerda que sí.
        $this->postJson('/api/experiments/brainy', ['mode' => false, 'changed' => false])->assertOk();
        $this->assertSame(1, (int) DB::table('experiment_participants')->sole()->changed);
        $this->assertSame(1, DB::table('experiment_participants')->count(), 'una fila por alumno');
    }

    public function test_cuenta_las_aperturas_de_brainy_y_los_botones_de_cuidado(): void
    {
        $this->on();
        Sanctum::actingAs($this->userIn('control'));
        $this->postJson('/api/experiments/brainy', ['mode' => false, 'opened' => true])->assertOk();
        $this->postJson('/api/experiments/brainy', ['mode' => false, 'opened' => true])->assertOk();
        $this->postJson('/api/experiments/brainy', ['mode' => false])->assertOk();
        $this->postJson('/api/pet/feed')->assertOk();
        $this->postJson('/api/pet/clean')->assertOk();

        $row = DB::table('experiment_participants')->sole();
        $this->assertSame([2, 2], [(int) $row->opens, (int) $row->care_taps]);
    }

    public function test_se_borra_con_la_cuenta(): void
    {
        $this->on();
        $user = $this->userIn('brainy');
        Sanctum::actingAs($user);
        $this->postJson('/api/experiments/brainy', ['mode' => true])->assertOk();
        $user->delete();
        $this->assertSame(0, DB::table('experiment_participants')->count());
    }

    // ---------- Informe ----------

    /** Mete a un alumno en el experimento hace $daysAgo días, con el modo indicado. */
    private function join(User $u, int $daysAgo, bool $mode, bool $changed = false, int $opens = 0, int $taps = 0): void
    {
        DB::table('experiment_participants')->insert([
            'user_id' => $u->id, 'experiment' => 'brainy', 'group' => BrainyExperiment::groupOf($u->id), 'entered_day' => $this->day(-$daysAgo),
            'mode' => $mode, 'changed' => $changed, 'opens' => $opens, 'care_taps' => $taps, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function xp(User $u, int $daysAgo, array $bySource, int $sessions = 0): void
    {
        DB::table('xp_days')->insert(['user_id' => $u->id, 'day' => $this->day(-$daysAgo), 'xp' => array_sum($bySource),
            'by_source' => json_encode($bySource), 'sessions' => $sessions]);
    }

    public function test_el_informe_compara_los_dos_grupos_desde_que_entro_cada_alumno(): void
    {
        $this->on($this->day(-30), min: 1);
        $b = $this->userIn('brainy');
        $c = $this->userIn('control');
        $this->join($b, 14, true, opens: 9, taps: 4);       // entró hace 14 días (2 semanas y 1 día = 15 días dentro)
        $this->join($c, 14, false, changed: false);

        // Grupo Brainy: practica el día 1 y el día 7. 3 días activos, 2 sesiones.
        $this->xp($b, 13, ['learn' => 10, 'review' => 9, 'review_again' => 1, 'ear' => 4], sessions: 1);   // día 1
        $this->xp($b, 7, ['review' => 6, 'mistake' => 5], sessions: 1);                                    // día 7
        $this->xp($b, 2, ['review' => 3]);
        $this->xp($b, 20, ['review' => 300, 'learn' => 250], sessions: 9);                                // antes de entrar: no cuenta
        // Grupo control: solo practica el día 1.
        $this->xp($c, 13, ['review' => 3, 'review_again' => 3]);

        $w1 = Word::create(['word' => 'apple', 'rank' => 1, 'translation' => 'manzana']);
        $w2 = Word::create(['word' => 'banana', 'rank' => 2, 'translation' => 'plátano']);
        $w3 = Word::create(['word' => 'cherry', 'rank' => 3, 'translation' => 'cereza']);
        DB::table('user_words')->insert([
            ['user_id' => $b->id, 'word_id' => $w1->id, 'introduced_at' => $this->day(-13), 'stability' => 30.0],
            ['user_id' => $b->id, 'word_id' => $w2->id, 'introduced_at' => $this->day(-13), 'stability' => 2.0],
            ['user_id' => $b->id, 'word_id' => $w3->id, 'introduced_at' => $this->day(-25), 'stability' => 40.0],   // de antes: fuerte, pero no «nueva»
            ['user_id' => $c->id, 'word_id' => $w1->id, 'introduced_at' => $this->day(-40), 'stability' => 1.0],
        ]);
        DB::table('listening_days')->insert([
            ['user_id' => $b->id, 'day' => $this->day(-13), 'ear_ok' => 3, 'ear_fail' => 1, 'repeats' => 0],
            ['user_id' => $b->id, 'day' => $this->day(-20), 'ear_ok' => 0, 'ear_fail' => 50, 'repeats' => 0],     // antes de entrar
        ]);
        $session = DB::table('speaking_sessions')->insertGetId(['user_id' => $b->id, 'day' => $this->day(-7), 'words' => 100, 'speech_ms' => 180000]);
        DB::table('speaking_mistakes')->insert([
            ['user_id' => $b->id, 'speaking_session_id' => $session, 'said' => 'TEXTO-PRIVADO', 'correct' => 'x', 'next_review' => $this->day(), 'created_at' => now()],
            ['user_id' => $b->id, 'speaking_session_id' => $session, 'said' => 'y', 'correct' => 'x', 'next_review' => $this->day(), 'created_at' => now()],
        ]);

        $r = $this->exp()->report();
        $gb = $r['groups']['brainy'];
        $gc = $r['groups']['control'];

        $this->assertSame([1, 1], [$gb['users'], $gc['users']]);
        $this->assertSame(['practice', 'learning'], $r['primary_metrics']);

        // Retención: los dos volvieron el día 1; el día 7 solo el de Brainy; el día 14 aún no se cumple entero.
        $this->assertSame(['active' => 1, 'of' => 1, 'percent' => 100], $gb['retention']['d1']);
        $this->assertSame(['active' => 1, 'of' => 1, 'percent' => 100], $gb['retention']['d7']);
        $this->assertSame(['active' => 0, 'of' => 0, 'percent' => null], $gb['retention']['d14']);
        $this->assertSame(100, $gc['retention']['d1']['percent']);
        $this->assertSame(0, $gc['retention']['d7']['percent']);

        // Práctica por alumno y semana (15 días dentro = 15/7 semanas).
        $perWeek = fn ($n) => round($n / (15 / 7), 1);
        $this->assertSame($perWeek(3), $gb['practice']['active_days_per_week']);
        $this->assertSame($perWeek(2), $gb['practice']['sessions_per_week']);
        $this->assertSame($perWeek(2), $gb['practice']['new_words_per_week']);
        $this->assertSame($perWeek(3 + 1 + 2 + 1), $gb['practice']['reviews_per_week']);      // 6 buenos + 1 fallado
        $this->assertSame($perWeek(4), $gb['practice']['ear_per_week']);
        $this->assertSame($perWeek(3), $gb['practice']['speaking_minutes_per_week']);
        $this->assertSame($perWeek(2 + 7 + 4 + 1 + 1), $gb['practice']['exercises_per_week']);  // nuevas + repasos + oído + 1 error repasado + 1 charla
        $this->assertSame($perWeek(1), $gc['practice']['active_days_per_week']);
        $this->assertSame($perWeek(4), $gc['practice']['reviews_per_week']);

        // Aprendizaje.
        $this->assertSame(['percent' => 75, 'of' => 4], $gb['learning']['ear_accuracy']);
        $this->assertSame(['percent' => 86, 'of' => 7], $gb['learning']['vocab_accuracy']);
        $this->assertSame(['percent' => 98, 'words' => 100], $gb['learning']['speaking_clean']);
        $this->assertSame(2.0, $gb['learning']['strong_words_per_user']);
        $this->assertSame(['percent' => 25, 'of' => 4], $gc['learning']['vocab_accuracy']);
        $this->assertSame(['percent' => null, 'of' => 0], $gc['learning']['ear_accuracy']);
        $this->assertSame(0.0, $gc['learning']['strong_words_per_user']);

        // Uso de Brainy (contexto).
        $this->assertSame(['mode_on' => 1, 'mode_off' => 0, 'turned_on_by_hand' => 0, 'turned_off_by_hand' => 0, 'opens' => 9, 'care_taps' => 4], $gb['brainy']);
        $this->assertSame(['mode_on' => 0, 'mode_off' => 1, 'turned_on_by_hand' => 0, 'turned_off_by_hand' => 0, 'opens' => 0, 'care_taps' => 0], $gc['brainy']);

        $this->assertStringNotContainsString('TEXTO-PRIVADO', json_encode($r), 'solo cifras');
        $this->assertStringNotContainsString($b->email, json_encode($r));
    }

    public function test_cuenta_quien_lo_encendio_o_apago_a_mano(): void
    {
        $this->on(min: 1);
        $this->join($this->userIn('brainy'), 3, false, changed: true);     // le tocó Brainy y lo apagó
        $this->join($this->userIn('brainy'), 3, true);
        $this->join($this->userIn('control'), 3, true, changed: true);     // control y lo encendió

        $r = $this->exp()->report();
        $this->assertSame([1, 1, 0, 1], array_values(array_slice($r['groups']['brainy']['brainy'], 0, 4)));
        $this->assertSame([1, 0, 1, 0], array_values(array_slice($r['groups']['control']['brainy'], 0, 4)));
    }

    public function test_avisa_claro_si_hay_pocos_alumnos_si_lleva_poco_o_si_esta_apagado(): void
    {
        $this->on($this->day(-30), min: 20);
        $this->join($this->userIn('brainy'), 5, true);
        $r = $this->exp()->report();
        $this->assertFalse($r['enough_data']);
        $this->assertStringContainsString('Muy pocos alumnos', $r['warning']);
        $this->assertStringContainsString('al menos 20', $r['warning']);

        // Con alumnos suficientes pero pocos días, avisa de esperar.
        $this->on($this->day(-5), min: 1);
        $this->join($this->userIn('control'), 5, false);
        $r = $this->exp()->report();
        $this->assertFalse($r['enough_data']);
        $this->assertStringContainsString('espera', $r['warning']);

        // Con alumnos y días suficientes: sin aviso.
        $this->on($this->day(-30), min: 1);
        $r = $this->exp()->report();
        $this->assertTrue($r['enough_data']);
        $this->assertNull($r['warning']);

        config(['experiments.brainy.enabled' => false]);
        $r = $this->exp()->report();
        $this->assertFalse($r['active']);
        $this->assertStringContainsString('apagado', $r['warning']);
    }

    public function test_el_comando_ensena_el_informe_y_rechaza_experimentos_desconocidos(): void
    {
        $this->on(min: 20);
        $this->join($this->userIn('brainy'), 5, true);

        $this->artisan('experiments:report', ['experiment' => 'brainy'])
            ->expectsOutputToContain('Experimento Modo Brainy')
            ->expectsOutputToContain('Muy pocos alumnos')
            ->assertSuccessful();
        $this->artisan('experiments:report', ['experiment' => 'brainy', '--json' => true])->expectsOutputToContain('"primary_metrics"')->assertSuccessful();
        $this->artisan('experiments:report', ['experiment' => 'otro'])->assertFailed();
    }

    public function test_el_panel_recibe_el_informe_sin_tocar_las_metricas_que_ya_habia(): void
    {
        $this->on(min: 1);
        $this->join($this->userIn('brainy'), 3, true);
        $data = (new MetricsSnapshot)->compute(CarbonImmutable::today(config('vocab.timezone')));

        $this->assertSame(1, $data['experiments']['brainy']['groups']['brainy']['users']);
        foreach (['users', 'active_today', 'retention_d1', 'daily', 'learning', 'suggestions'] as $key) {
            $this->assertArrayHasKey($key, $data);
        }
    }
}
