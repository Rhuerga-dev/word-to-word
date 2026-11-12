<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PronunciationTipsTest extends TestCase
{
    use RefreshDatabase;

    private function wav(): UploadedFile
    {
        return UploadedFile::fake()->createWithContent('voz.wav', str_repeat("\0", 2000));
    }

    public function test_returns_the_weak_words_and_sounds_and_feeds_the_workshop(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        config(['vocab.azure_speech.key' => 'test-key']);
        Http::fake(['*' => Http::response(['RecognitionStatus' => 'Success', 'NBest' => [[
            'Display' => 'I sink so.',
            'PronunciationAssessment' => ['PronScore' => 55, 'AccuracyScore' => 50, 'FluencyScore' => 80, 'CompletenessScore' => 100],
            'Words' => [
                ['Word' => 'I', 'PronunciationAssessment' => ['AccuracyScore' => 98, 'ErrorType' => 'None'], 'Phonemes' => []],
                ['Word' => 'think', 'PronunciationAssessment' => ['AccuracyScore' => 40, 'ErrorType' => 'Mispronunciation'], 'Phonemes' => [
                    ['Phoneme' => 'θ', 'PronunciationAssessment' => ['AccuracyScore' => 12]],
                    ['Phoneme' => 'ɪ', 'PronunciationAssessment' => ['AccuracyScore' => 90]],
                    ['Phoneme' => 'ŋ', 'PronunciationAssessment' => ['AccuracyScore' => 50]],
                ]],
                ['Word' => 'so', 'PronunciationAssessment' => ['AccuracyScore' => 95, 'ErrorType' => 'None'], 'Phonemes' => []],
            ],
        ]]])]);

        $r = $this->post('/api/pronunciation/tips', ['text' => 'I think so!', 'audio' => $this->wav()])->assertOk();

        $r->assertJsonPath('available', true);
        $this->assertSame([['word' => 'think', 'accuracy' => 40, 'error' => 'Mispronunciation', 'phonemes' => ['θ', 'ŋ']]], $r->json('words'));
        $this->assertSame(['θ', 'ŋ'], DB::table('phoneme_errors')->where('user_id', $user->id)->orderBy('phoneme', 'desc')->pluck('phoneme')->all());
        // Sin XP: es una ayuda, no un ejercicio.
        $this->assertSame(0, DB::table('xp_days')->where('user_id', $user->id)->count());
    }

    public function test_without_azure_it_says_so_and_the_app_uses_spelling_hints(): void
    {
        Sanctum::actingAs(User::factory()->create());
        config(['vocab.azure_speech.key' => null]);

        $this->post('/api/pronunciation/tips', ['text' => 'think', 'audio' => $this->wav()])
            ->assertOk()->assertJson(['available' => false, 'words' => []]);
    }
}
