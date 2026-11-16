<?php

namespace Tests\Feature;

use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/** Contenido de palabras preparado de antemano: rellena huecos sin llamar a la IA y con las mismas reglas. */
class WordContentImportTest extends TestCase
{
    use RefreshDatabase;

    private function file(array $data): string
    {
        $path = tempnam(sys_get_temp_dir(), 'w2w').'.json';
        file_put_contents($path, json_encode($data));

        return $path;
    }

    public function test_rellena_solo_lo_vacio_y_sin_llamar_a_la_ia(): void
    {
        Http::fake();
        $rent = Word::create(['word' => 'rent', 'rank' => 1, 'translation' => 'alquiler']);
        $keep = Word::create(['word' => 'house', 'rank' => 2, 'translation' => 'casa', 'definition' => 'a building where a family lives']);

        $path = $this->file([
            'rent' => ['definition' => 'money you pay each month to live in a place', 'definition_easy' => 'money for a home', 'sentence_long' => 'I pay the rent on the first day of every month to my landlord.'],
            'house' => ['definition' => 'something new'],
            'nope' => ['definition' => 'a word that is not in the list'],
        ]);
        $this->artisan('words:content', ['--path' => $path])->assertSuccessful();

        $rent->refresh();
        $this->assertSame('money you pay each month to live in a place', $rent->definition);
        $this->assertSame('money for a home', $rent->definition_easy);
        $this->assertStringContainsString('rent', $rent->sentence_long);
        $this->assertSame('a building where a family lives', $keep->refresh()->definition);   // nunca pisa
        Http::assertNothingSent();
    }

    public function test_aplica_las_reglas_de_calidad(): void
    {
        $w = Word::create(['word' => 'borrow', 'rank' => 1, 'translation' => 'pedir prestado']);
        $path = $this->file(['borrow' => [
            'definition' => 'to borrow something from a friend',            // contiene la palabra
            'definition_easy' => 'take now, give back later',
            'sentence_long' => 'Can I take your pen for a minute please?',  // NO contiene la palabra
        ]]);
        $this->artisan('words:content', ['--path' => $path])->assertSuccessful();

        $w->refresh();
        $this->assertNull($w->definition);
        $this->assertSame('take now, give back later', $w->definition_easy);
        $this->assertNull($w->sentence_long);
    }

    public function test_dry_run_no_guarda(): void
    {
        $w = Word::create(['word' => 'rent', 'rank' => 1, 'translation' => 'alquiler']);
        $path = $this->file(['rent' => ['definition' => 'money you pay to live in a place']]);
        $this->artisan('words:content', ['--path' => $path, '--dry-run' => true])->assertSuccessful();
        $this->assertNull($w->refresh()->definition);
    }
}
