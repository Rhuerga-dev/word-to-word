<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** El alumno le pone nombre a su mascota y solo ve su nacimiento una vez. */
class PetNameTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create();
        Sanctum::actingAs($this->user);
    }

    public function test_nace_llamandose_brainy_y_sin_haber_sido_presentada(): void
    {
        $this->getJson('/api/pet')->assertOk()
            ->assertJsonPath('name', 'Brainy')->assertJsonPath('named', false)->assertJsonPath('welcomed', false);
    }

    public function test_ponerle_nombre_lo_guarda_y_ya_no_vuelve_a_presentarse(): void
    {
        $this->putJson('/api/pet/name', ['name' => '  Luna   Azul '])->assertOk()
            ->assertJsonPath('name', 'Luna Azul')->assertJsonPath('named', true)->assertJsonPath('welcomed', true);
        $this->getJson('/api/pet')->assertJsonPath('name', 'Luna Azul')->assertJsonPath('welcomed', true);

        // Se puede cambiar después.
        $this->putJson('/api/pet/name', ['name' => 'Ñandú 2'])->assertOk()->assertJsonPath('name', 'Ñandú 2');
        $this->assertSame(1, DB::table('pets')->where('user_id', $this->user->id)->count());
    }

    public function test_decir_luego_la_deja_como_brainy_pero_ya_presentada(): void
    {
        $this->putJson('/api/pet/name', ['name' => null])->assertOk()
            ->assertJsonPath('name', 'Brainy')->assertJsonPath('named', false)->assertJsonPath('welcomed', true);
        $this->putJson('/api/pet/name', ['name' => ''])->assertOk()->assertJsonPath('name', 'Brainy');
    }

    public function test_decir_luego_no_borra_un_nombre_ya_puesto(): void
    {
        $this->putJson('/api/pet/name', ['name' => 'Luna'])->assertOk();
        $this->putJson('/api/pet/name', ['name' => null])->assertOk()->assertJsonPath('name', 'Luna');
        // Llamarla «Brainy» es volver al nombre de siempre.
        $this->putJson('/api/pet/name', ['name' => 'Brainy'])->assertOk()->assertJsonPath('name', 'Brainy')->assertJsonPath('named', false);
    }

    public function test_valida_el_nombre(): void
    {
        $this->withoutMiddleware(\Illuminate\Routing\Middleware\ThrottleRequests::class);
        foreach ([['name' => 'A'], ['name' => str_repeat('a', 21)], ['name' => '<b>x</b>'], ['name' => '🙂🙂🙂'], ['name' => ' -Luna'],
            ['name' => ['Luna']], ['name' => 'Luna; drop'], ['name' => 'Luna/../x']] as $bad) {
            $this->putJson('/api/pet/name', $bad)->assertStatus(422);
        }
        // Saltos de línea y espacios repetidos se quedan en un solo espacio.
        $this->putJson('/api/pet/name', ['name' => "Lu\nna"])->assertOk()->assertJsonPath('name', 'Lu na');
        foreach (['Lu', 'José María', "O'Neil", 'R2-D2', str_repeat('a', 20), 'Мозг', '小脑'] as $ok) {
            $this->putJson('/api/pet/name', ['name' => $ok])->assertOk()->assertJsonPath('name', $ok);
        }
    }

    public function test_cada_alumno_nombra_solo_la_suya_y_hace_falta_sesion(): void
    {
        $other = User::factory()->create();
        $this->putJson('/api/pet/name', ['name' => 'Luna', 'user_id' => $other->id])->assertOk();
        Sanctum::actingAs($other);
        $this->getJson('/api/pet')->assertJsonPath('name', 'Brainy')->assertJsonPath('welcomed', false);

        $this->app['auth']->forgetGuards();
        $this->putJson('/api/pet/name', ['name' => 'Luna'])->assertUnauthorized();
    }

    public function test_frena_las_rafagas(): void
    {
        for ($i = 0; $i < 10; $i++) {
            $this->putJson('/api/pet/name', ['name' => 'Luna'])->assertOk();
        }
        $this->putJson('/api/pet/name', ['name' => 'Luna'])->assertStatus(429);
    }

    public function test_los_botones_de_cuidado_siguen_funcionando(): void
    {
        $this->putJson('/api/pet/name', ['name' => 'Luna'])->assertOk();
        $this->postJson('/api/pet/feed')->assertOk()->assertJsonPath('pet.name', 'Luna');
        $this->postJson('/api/pet/name')->assertStatus(405);   // «name» no es un botón de cuidado
    }
}
