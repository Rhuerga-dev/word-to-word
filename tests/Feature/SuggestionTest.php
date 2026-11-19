<?php

namespace Tests\Feature;

use App\Console\Commands\MetricsSnapshot;
use App\Models\Suggestion;
use App\Models\User;
use App\Services\DemoService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Sugerencias de los alumnos: quién puede enviar, qué se valida, los topes y lo que ve el panel. */
class SuggestionTest extends TestCase
{
    use RefreshDatabase;

    private function body(array $extra = []): array
    {
        return array_merge(['type' => 'idea', 'message' => 'Me gustaría un modo oscuro.', 'app_version' => '1.0.14+16',
            'platform' => 'android', 'screen' => 'settings'], $extra);
    }

    public function test_hace_falta_sesion(): void
    {
        $this->postJson('/api/suggestions', $this->body())->assertUnauthorized();
        $this->assertSame(0, Suggestion::count());
    }

    public function test_guarda_la_sugerencia_a_nombre_del_usuario_del_token(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        Sanctum::actingAs($user);

        // El cliente intenta colar otro dueño y otro estado: se ignoran.
        $this->postJson('/api/suggestions', $this->body(['user_id' => $other->id, 'status' => 'done', 'message' => '   Me gustaría un modo oscuro.  ']))
            ->assertCreated()->assertJsonPath('ok', true);

        $s = Suggestion::sole();
        $this->assertSame($user->id, $s->user_id);
        $this->assertSame('new', $s->status);
        $this->assertSame(['idea', 'Me gustaría un modo oscuro.', '1.0.14+16', 'android', 'settings'],
            [$s->type, $s->message, $s->app_version, $s->platform, $s->screen]);
    }

    public function test_los_datos_del_telefono_son_opcionales(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/suggestions', ['type' => 'bug', 'message' => 'No suena el audio.'])->assertCreated();
        $this->assertNull(Suggestion::sole()->platform);
    }

    public function test_valida_el_tipo_el_texto_y_los_datos_del_telefono(): void
    {
        $this->withoutMiddleware(ThrottleRequests::class);   // aquí se prueba la validación, no la ráfaga
        Sanctum::actingAs(User::factory()->create());
        $bad = [
            ['type' => 'spam'], ['type' => ''], ['type' => ['idea']],
            ['message' => 'hola'], ['message' => '   a   '], ['message' => str_repeat('a', 2001)], ['message' => ['x']],
            ['platform' => 'windows'], ['app_version' => '<script>'], ['app_version' => str_repeat('1', 31)],
            ['screen' => '<b>x</b>'], ['screen' => str_repeat('a', 61)],
        ];
        foreach ($bad as $extra) {
            $this->postJson('/api/suggestions', $this->body($extra))->assertStatus(422);
        }
        $this->assertSame(0, Suggestion::count());

        $this->postJson('/api/suggestions', $this->body(['message' => str_repeat('a', 2000), 'type' => 'other', 'platform' => 'web']))->assertCreated();
    }

    public function test_la_demo_no_puede_enviar(): void
    {
        Sanctum::actingAs(User::factory()->create(['email' => 'demo-x@'.DemoService::DOMAIN]));
        $this->postJson('/api/suggestions', $this->body())->assertForbidden()->assertJsonPath('demo', true);
        $this->assertSame(0, Suggestion::count());
    }

    public function test_frena_las_rafagas_cinco_cada_diez_minutos(): void
    {
        Sanctum::actingAs(User::factory()->create());
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/suggestions', $this->body())->assertCreated();
        }
        $this->postJson('/api/suggestions', $this->body())->assertStatus(429);
        $this->assertSame(5, Suggestion::count());
    }

    public function test_tope_diario_por_alumno(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $row = fn (int $id, $at) => ['user_id' => $id, 'type' => 'idea', 'message' => 'una idea', 'status' => 'new', 'created_at' => $at, 'updated_at' => $at];
        DB::table('suggestions')->insert(array_fill(0, Suggestion::DAILY_PER_USER, $row($user->id, now()->subHours(2))));

        Sanctum::actingAs($user);
        $this->postJson('/api/suggestions', $this->body())->assertStatus(429);

        // El tope es de cada alumno: otro sí puede.
        Sanctum::actingAs($other);
        $this->postJson('/api/suggestions', $this->body())->assertCreated();

        // Y al día siguiente se renueva.
        DB::table('suggestions')->where('user_id', $user->id)->update(['created_at' => now()->subHours(25)]);
        Sanctum::actingAs($user);
        $this->postJson('/api/suggestions', $this->body())->assertCreated();
    }

    public function test_se_borran_con_la_cuenta(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $this->postJson('/api/suggestions', $this->body())->assertCreated();
        $user->delete();
        $this->assertSame(0, Suggestion::count());
    }

    public function test_el_panel_ve_cuantas_sugerencias_nuevas_hay(): void
    {
        $compute = fn () => (new MetricsSnapshot)->compute(CarbonImmutable::today(config('vocab.timezone')));
        $this->assertSame(['new' => 0, 'new_by_type' => ['idea' => 0, 'bug' => 0, 'other' => 0], 'last_7d' => 0, 'total' => 0], $compute()['suggestions']);

        $u = User::factory()->create();
        $row = fn (string $type, string $status, $at) => ['user_id' => $u->id, 'type' => $type, 'message' => 'TEXTO-PRIVADO', 'status' => $status, 'created_at' => $at, 'updated_at' => $at];
        DB::table('suggestions')->insert([
            $row('idea', 'new', now()), $row('idea', 'new', now()), $row('bug', 'new', now()->subDays(10)),
            $row('other', 'done', now()), $row('bug', 'dismissed', now()->subDays(30)),
        ]);

        $data = $compute();
        $this->assertSame(['new' => 3, 'new_by_type' => ['idea' => 2, 'bug' => 1, 'other' => 0], 'last_7d' => 3, 'total' => 5], $data['suggestions']);
        $this->assertStringNotContainsString('TEXTO-PRIVADO', json_encode($data), 'al panel solo van cifras, nunca el texto');
        // Lo que ya había sigue ahí.
        foreach (['users', 'active_today', 'retention_d1', 'daily', 'learning'] as $key) {
            $this->assertArrayHasKey($key, $data);
        }
    }
}
