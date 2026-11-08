<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PronunciationLabTest extends TestCase
{
    use RefreshDatabase;

    private function user(): User
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        DB::table('phoneme_errors')->insert([
            ['user_id' => $user->id, 'phoneme' => 'θ', 'count' => 9, 'last_word' => 'think', 'created_at' => now(), 'updated_at' => now()],
            ['user_id' => $user->id, 'phoneme' => 'v', 'count' => 3, 'last_word' => 'very', 'created_at' => now(), 'updated_at' => now()],
        ]);

        return $user;
    }

    public function test_lists_the_hardest_sounds_first(): void
    {
        $this->user();
        $sounds = $this->getJson('/api/pronunciation/sounds')->assertOk()->json('sounds');
        $this->assertSame(['θ', 'v'], array_column($sounds, 'phoneme'));
        $this->assertTrue($sounds[0]['due']);
    }

    public function test_passing_spaces_the_next_workshop_and_failing_brings_it_back_tomorrow(): void
    {
        $user = $this->user();
        $r = $this->postJson('/api/pronunciation/sounds/result', ['phoneme' => 'θ', 'passed' => true, 'score' => 85])->assertOk();
        $this->assertSame(1, $r->json('stage'));
        $this->assertSame(1, $r->json('days'));

        // Mismo día otra vez: no adelanta.
        $this->postJson('/api/pronunciation/sounds/result', ['phoneme' => 'θ', 'passed' => true])->assertJsonPath('stage', 1);

        $user->increment('day_offset');
        $this->postJson('/api/pronunciation/sounds/result', ['phoneme' => 'θ', 'passed' => true])->assertJsonPath('stage', 2)->assertJsonPath('days', 3);

        $user->increment('day_offset');
        $this->postJson('/api/pronunciation/sounds/result', ['phoneme' => 'θ', 'passed' => false])->assertJsonPath('stage', 1)->assertJsonPath('days', 1);

        $sounds = collect($this->getJson('/api/pronunciation/sounds')->json('sounds'));
        $this->assertFalse($sounds->firstWhere('phoneme', 'θ')['due']);
        $this->assertSame('v', $sounds->first()['phoneme']); // lo que toca hoy va primero
    }

    public function test_four_spaced_passes_master_the_sound(): void
    {
        $user = $this->user();
        foreach (range(1, 4) as $i) {
            $r = $this->postJson('/api/pronunciation/sounds/result', ['phoneme' => 'v', 'passed' => true]);
            $user->increment('day_offset');
        }
        $r->assertJsonPath('mastered', true);
        $this->assertSame('v', collect($this->getJson('/api/pronunciation/sounds')->json('sounds'))->last()['phoneme']);
    }

    public function test_assess_returns_the_score_of_the_practised_sound(): void
    {
        config(['vocab.azure_speech.key' => 'test-key']);
        Http::fake(['*' => Http::response(['RecognitionStatus' => 'Success', 'NBest' => [[
            'Display' => 'Think three.',
            'PronunciationAssessment' => ['PronScore' => 70, 'AccuracyScore' => 70, 'FluencyScore' => 90, 'CompletenessScore' => 100],
            'Words' => [
                ['Word' => 'think', 'PronunciationAssessment' => ['AccuracyScore' => 60, 'ErrorType' => 'None'],
                    'Phonemes' => [['Phoneme' => 'θ', 'PronunciationAssessment' => ['AccuracyScore' => 40]], ['Phoneme' => 'ɪ', 'PronunciationAssessment' => ['AccuracyScore' => 95]]]],
                ['Word' => 'three', 'PronunciationAssessment' => ['AccuracyScore' => 80, 'ErrorType' => 'None'],
                    'Phonemes' => [['Phoneme' => 'θ', 'PronunciationAssessment' => ['AccuracyScore' => 80]], ['Phoneme' => 'r', 'PronunciationAssessment' => ['AccuracyScore' => 90]]]],
            ],
        ]]])]);

        $user = $this->user();
        $audio = UploadedFile::fake()->createWithContent('voz.wav', 'RIFF....WAVE');
        $this->post('/api/pronunciation/assess', ['text' => 'Think three.', 'phoneme' => 'θ', 'audio' => $audio], ['Accept' => 'application/json'])
            ->assertOk()->assertJsonPath('score', 70)->assertJsonPath('target_score', 60);

        // La práctica no suma errores al historial.
        $this->assertSame(9, (int) DB::table('phoneme_errors')->where(['user_id' => $user->id, 'phoneme' => 'θ'])->value('count'));
    }
}
