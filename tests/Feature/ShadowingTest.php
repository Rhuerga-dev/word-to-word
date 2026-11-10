<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Shadowing: textos originales de tu nivel, solo con frases que la evaluación acepta, y reutilizados. */
class ShadowingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['vocab.anthropic.key' => 'test-key']);
        Sanctum::actingAs(User::factory()->create(['cefr_level' => 'B1']));
    }

    private function fake(): void
    {
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => json_encode(['title' => 'Coffee time', 'sentences' => [
            "Hi, can I get a large coffee, please?",
            "Sure, do you want milk with that?",
            "It costs 5 dollars.",                       // número: no vale
            "Yeah, just a little bit, thanks.",
            "\"Have a great day!\"",                     // comillas: no vale
            "You're welcome, see you tomorrow!",
        ]])]]])]);
    }

    public function test_the_text_keeps_only_valid_sentences_and_is_reused_the_same_day(): void
    {
        $this->fake();
        $r = $this->getJson('/api/speaking/shadowing')->assertOk()->assertJsonPath('title', 'Coffee time')->assertJsonPath('level', 'B1');
        $this->assertSame(["Hi, can I get a large coffee, please?", "Sure, do you want milk with that?", "Yeah, just a little bit, thanks.", "You're welcome, see you tomorrow!"], $r->json('sentences'));

        $this->getJson('/api/speaking/shadowing')->assertOk();
        Http::assertSentCount(1);                                  // segunda vez: de la caché

        $this->getJson('/api/speaking/shadowing?skip=1')->assertOk(); // otro tema: texto nuevo
        Http::assertSentCount(2);
    }

    public function test_a_text_with_too_few_valid_sentences_is_an_error(): void
    {
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => '{"title":"x","sentences":["1 2 3","ok"]}']]])]);
        $this->getJson('/api/speaking/shadowing')->assertStatus(502);
    }
}
