<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Traducciones de la interfaz desde el API (lang/en.json), como en CuPay. */
class UiTranslationsTest extends TestCase
{
    use RefreshDatabase;

    private string $dir;

    protected function setUp(): void
    {
        parent::setUp();
        $this->dir = storage_path('framework/testing/i18n-'.uniqid());
        File::ensureDirectoryExists($this->dir);
        File::put($this->dir.'/en.json', json_encode(['Hoy' => 'Today', 'Unidad {0} de {1}' => 'Unit {0} of {1}']));
        config(['i18n.path' => $this->dir, 'i18n.learned_path' => $this->dir.'/learned', 'vocab.anthropic.key' => 'test-key']);
    }

    protected function tearDown(): void
    {
        File::deleteDirectory($this->dir);
        parent::tearDown();
    }

    public function test_las_apps_descargan_las_traducciones_con_version(): void
    {
        $r = $this->getJson('/api/i18n/en')->assertOk()->assertJsonPath('strings.Hoy', 'Today');
        $etag = $r->headers->get('ETag');
        $this->assertNotEmpty($r->json('version'));

        // Sin cambios: 304 y nada que descargar.
        $this->get('/api/i18n/en', ['If-None-Match' => $etag])->assertStatus(304);
        $this->getJson('/api/i18n/fr')->assertNotFound();
    }

    public function test_solo_se_anotan_los_textos_que_faltan(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/i18n/missing', ['lang' => 'en', 'keys' => ['Hoy', 'Tus palabras', 'Tus palabras']])
            ->assertOk()->assertJsonPath('queued', 1);
        $this->postJson('/api/i18n/missing', ['lang' => 'en', 'keys' => ['Tus palabras']])->assertJsonPath('queued', 0);

        $this->assertSame(1, DB::table('i18n_missing')->count());
        $this->assertSame(2, DB::table('i18n_missing')->value('hits'));
    }

    public function test_valida_lo_que_mandan_las_apps(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/i18n/missing', ['lang' => 'xx', 'keys' => ['a']])->assertStatus(422);
        $this->postJson('/api/i18n/missing', ['lang' => 'en', 'keys' => array_fill(0, 51, 'a')])->assertStatus(422);
        $this->postJson('/api/i18n/missing', ['lang' => 'en', 'keys' => [str_repeat('a', 301)]])->assertStatus(422);
        $this->postJson('/api/i18n/missing', ['lang' => 'en', 'keys' => ['a']])->assertOk();
    }

    public function test_hace_falta_sesion_para_anotar_textos(): void
    {
        $this->postJson('/api/i18n/missing', ['lang' => 'en', 'keys' => ['Hola']])->assertUnauthorized();
    }

    public function test_la_ia_traduce_los_pendientes_y_se_guardan_fuera_de_git(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/i18n/missing', ['lang' => 'en', 'keys' => ['Tus palabras', 'Nuevas hoy: {0} de {1}', 'Roto {0}']]);
        Http::fake(['api.anthropic.com/*' => Http::response(['content' => [['type' => 'text', 'text' => json_encode([
            'Tus palabras' => 'Your words',
            'Nuevas hoy: {0} de {1}' => 'New today: {0} of {1}',
            'Roto {0}' => 'Broken', // pierde el hueco: no se acepta
        ])]]])]);

        $this->artisan('i18n:translate')->assertSuccessful();

        $file = json_decode(File::get($this->dir.'/learned/en.json'), true);
        $this->assertSame('Your words', $file['Tus palabras']);
        $this->assertSame('New today: {0} of {1}', $file['Nuevas hoy: {0} de {1}']);
        $this->assertArrayNotHasKey('Roto {0}', $file);
        // lang/en.json (en git) no se toca: así no se pausa la publicación automática.
        $this->assertSame(['Hoy' => 'Today', 'Unidad {0} de {1}' => 'Unit {0} of {1}'], json_decode(File::get($this->dir.'/en.json'), true));
        $this->assertFileDoesNotExist($this->dir.'/en.json.lock');
        // Lo traducido sale de la cola; lo que falló queda para otro intento.
        $this->assertSame(['Roto {0}'], DB::table('i18n_missing')->pluck('key')->all());
        $this->getJson('/api/i18n/en')->assertJsonPath('strings.Tus palabras', 'Your words');
    }

    public function test_las_revisadas_mandan_y_la_version_cambia_con_lo_aprendido(): void
    {
        $before = $this->getJson('/api/i18n/en')->json('version');
        File::ensureDirectoryExists($this->dir.'/learned');
        File::put($this->dir.'/learned/en.json', json_encode(['Hoy' => 'Nowadays', 'Salir' => 'Exit']));

        $r = $this->getJson('/api/i18n/en');
        $r->assertJsonPath('strings.Hoy', 'Today')->assertJsonPath('strings.Salir', 'Exit');
        $this->assertNotSame($before, $r->json('version'));
    }

    public function test_promote_pasa_lo_aprendido_a_lang(): void
    {
        File::ensureDirectoryExists($this->dir.'/learned');
        File::put($this->dir.'/learned/en.json', json_encode(['Hoy' => 'Nowadays', 'Salir' => 'Exit']));

        $this->artisan('i18n:promote')->assertSuccessful();

        $lang = json_decode(File::get($this->dir.'/en.json'), true);
        $this->assertSame('Exit', $lang['Salir']);
        $this->assertSame('Today', $lang['Hoy']);
        $this->assertFileDoesNotExist($this->dir.'/learned/en.json');
    }
}
