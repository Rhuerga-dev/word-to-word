<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Word;
use Database\Seeders\FamilyWordSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FamilyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Una palabra general que también es del cuerpo: el seeder solo le pone la familia.
        Word::create(['word' => 'hand', 'rank' => 1, 'source' => 'ngsl', 'translation' => 'mano', 'example' => 'My *hand*.', 'example_es' => 'Mi mano.']);
        Word::create(['word' => 'time', 'rank' => 2, 'source' => 'ngsl', 'translation' => 'tiempo', 'example' => 'No *time*.', 'example_es' => 'Sin tiempo.']);
        $this->seed(FamilyWordSeeder::class);
    }

    private function user(array $attrs = []): User
    {
        $user = User::factory()->create($attrs + ['daily_new' => 3, 'freelance_pack' => false]);
        Sanctum::actingAs($user);

        return $user;
    }

    public function test_seeder_tags_existing_words_and_adds_new_ones(): void
    {
        $hand = Word::firstWhere('word', 'hand');
        $this->assertSame('body', $hand->category);
        $this->assertSame('ngsl', $hand->source);
        $this->assertSame('family', Word::firstWhere('word', 'apple')->source);
        $this->assertSame('fruits', Word::firstWhere('word', 'apple')->category);

        $this->seed(FamilyWordSeeder::class); // otra vez: sin duplicados
        $this->assertSame(1, Word::where('word', 'apple')->count());
    }

    public function test_families_list_with_progress(): void
    {
        $this->user();
        $res = $this->getJson('/api/families')->assertOk();
        $fruits = collect($res->json('families'))->firstWhere('key', 'fruits');
        $this->assertSame('Frutas', $fruits['label']);
        $this->assertGreaterThan(5, $fruits['total']);
        $this->assertSame(0, $fruits['learned']);
    }

    public function test_choosing_a_family_brings_its_words_first(): void
    {
        $this->user();
        $this->putJson('/api/settings', ['family' => 'fruits'])->assertOk()->assertJsonPath('family', 'fruits');

        $cards = $this->getJson('/api/today')->assertOk()->json('cards');
        $this->assertCount(3, $cards);
        foreach ($cards as $c) {
            $this->assertSame('fruits', $c['category']);
            $this->assertSame('Frutas', $c['family']['label']);
        }
    }

    public function test_without_family_general_list_comes_first_and_family_words_are_not_in_levels(): void
    {
        $this->user();
        $cards = $this->getJson('/api/today')->json('cards');
        $this->assertSame(['hand', 'time'], array_slice(array_column($cards, 'word'), 0, 2));
        $this->assertSame(0, app(\App\Services\LevelService::class)->general()->where('source', 'family')->count());
    }

    public function test_unknown_family_is_rejected_and_null_clears_it(): void
    {
        $this->user(['family' => 'fruits']);
        $this->putJson('/api/settings', ['family' => 'spaceships'])->assertStatus(422);
        $this->putJson('/api/settings', ['family' => null])->assertOk()->assertJsonPath('family', null);
    }
}
