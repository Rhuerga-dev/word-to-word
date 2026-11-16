<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Escenas para recordar una palabra: primero las preparadas (sin IA), si no, la IA como antes. */
class AidBankTest extends TestCase
{
    use RefreshDatabase;

    public function test_prepared_scenes_need_no_ai(): void
    {
        Http::fake();
        $path = tempnam(sys_get_temp_dir(), 'aids').'.json';
        file_put_contents($path, json_encode(['Clothes' => ['"Clocs": zuecos gigantes escupiendo ropa.', '"Clo": un payaso de ropa.', '"Close": puerta que se viste.']]));
        config(['vocab.aids_bank' => $path, 'vocab.anthropic.key' => null]);
        Sanctum::actingAs(User::factory()->create());
        $w = Word::create(['word' => 'clothes', 'rank' => 1, 'translation' => 'ropa']);

        $this->postJson("/api/words/{$w->id}/aid/suggest")->assertOk()->assertJsonCount(3, 'suggestions')
            ->assertJsonPath('suggestions.0', '"Clocs": zuecos gigantes escupiendo ropa.');
        Http::assertNothingSent();
    }

    public function test_a_word_without_scenes_still_asks_the_ai(): void
    {
        config(['vocab.aids_bank' => '/no/existe.json', 'vocab.anthropic.key' => 'test-key']);
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => "\"Rent\": renta.\n\"Ren\": un reno paga.\n\"Rente\": casa cara."]]])]);
        Sanctum::actingAs(User::factory()->create());
        $w = Word::create(['word' => 'rent', 'rank' => 1, 'translation' => 'alquiler']);

        $this->postJson("/api/words/{$w->id}/aid/suggest")->assertOk()->assertJsonCount(3, 'suggestions');
        Http::assertSentCount(1);
    }
}
