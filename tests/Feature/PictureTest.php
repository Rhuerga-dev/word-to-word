<?php

namespace Tests\Feature;

use App\Models\SpeakingSession;
use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\LevelService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Describe la imagen: foto de Unsplash, la IA ve la misma foto, palabras que faltaron a tus fichas. */
class PictureTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    private const PHOTO = 'https://images.unsplash.com/photo-123?w=1080';

    protected function setUp(): void
    {
        parent::setUp();
        config(['vocab.anthropic.key' => 'test-key', 'services.unsplash.key' => 'test-unsplash']);
        $this->user = User::factory()->create(['cefr_level' => 'B1']);
        Sanctum::actingAs($this->user);
    }

    private function talk(): SpeakingSession
    {
        return SpeakingSession::create(['user_id' => $this->user->id, 'scenario' => 'picture', 'day' => today(config('vocab.timezone'))->toDateString()]);
    }

    public function test_a_photo_comes_from_unsplash_with_its_author_and_the_download_is_reported(): void
    {
        Http::fake([
            'api.unsplash.com/photos/random*' => Http::response(['id' => 'abc', 'urls' => ['regular' => self::PHOTO], 'alt_description' => 'a kitchen',
                'user' => ['name' => 'Ana Foto', 'links' => ['html' => 'https://unsplash.com/@ana']], 'links' => ['download_location' => 'https://api.unsplash.com/photos/abc/download']]),
            'api.unsplash.com/photos/abc/download*' => Http::response(['url' => 'x']),
        ]);

        $this->getJson('/api/speaking/picture')->assertOk()->assertJsonPath('url', self::PHOTO)->assertJsonPath('author', 'Ana Foto')
            ->assertJsonPath('author_url', 'https://unsplash.com/@ana?utm_source=word_to_word&utm_medium=referral');
        Http::assertSent(fn (HttpRequest $r) => str_contains($r->url(), '/photos/abc/download') && $r->header('Authorization')[0] === 'Client-ID test-unsplash');
        $this->getJson('/api/config')->assertJsonPath('pictures', true);
    }

    public function test_without_a_key_there_are_no_photos(): void
    {
        config(['services.unsplash.key' => null]);
        $this->getJson('/api/speaking/picture')->assertStatus(503);
        $this->getJson('/api/config')->assertJsonPath('pictures', false);
    }

    public function test_the_ai_sees_the_same_photo_and_returns_missed_words_a_better_version_and_mistakes(): void
    {
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => implode("\n", [
            'COMMENT: Nice description of the kitchen!',
            'MISSED: stove | estufa | The pan is on the *stove*.',
            'MISSED: cutting board | tabla de cortar | She chops onions on a *cutting board*.',
            'MISSED: 123bad | x | y',
            'BETTER: A woman is cooking in a bright kitchen.',
            'FEEDBACK: ¡Bien!',
            'FIX: she cook => she is cooking | presente continuo para lo que pasa ahora | tense',
        ])]]])]);
        $s = $this->talk();

        $r = $this->postJson("/api/speaking/sessions/{$s->id}/picture", ['text' => 'a woman she cook in the kitchen', 'image_url' => self::PHOTO])->assertOk();
        $r->assertJsonPath('comment', 'Nice description of the kitchen!')->assertJsonPath('better', 'A woman is cooking in a bright kitchen.')
            ->assertJsonPath('missed.0.word', 'stove')->assertJsonPath('missed.1.word', 'cutting board')->assertJsonPath('mistakes.0.category', 'tense');
        $this->assertCount(2, $r->json('missed'));

        Http::assertSent(fn (HttpRequest $req) => ($req->data()['messages'][0]['content'][0]['source']['url'] ?? null) === self::PHOTO);
    }

    public function test_only_unsplash_photos_and_own_picture_sessions_are_accepted(): void
    {
        Http::fake();
        $s = $this->talk();
        foreach (['http://images.unsplash.com/x', 'https://evil.example/x.jpg', 'https://images.unsplash.com.evil.io/x', 'file:///etc/passwd'] as $bad) {
            $this->postJson("/api/speaking/sessions/{$s->id}/picture", ['text' => 'hello there', 'image_url' => $bad])->assertStatus(422);
        }
        $other = SpeakingSession::create(['user_id' => User::factory()->create()->id, 'scenario' => 'picture', 'day' => today()]);
        $this->postJson("/api/speaking/sessions/{$other->id}/picture", ['text' => 'hi', 'image_url' => self::PHOTO])->assertNotFound();
        Http::assertNothingSent();
    }

    public function test_missed_words_go_to_your_cards_and_never_to_other_students(): void
    {
        $this->postJson('/api/words/personal', ['word' => 'Stove', 'translation' => 'estufa', 'example' => 'The pan is on the stove.'])
            ->assertOk()->assertJsonPath('added', true)->assertJsonPath('word', 'stove');
        $w = Word::firstWhere('word', 'stove');
        $this->assertSame(LevelService::PERSONAL, $w->source);
        $this->assertSame('The pan is on the *stove*.', $w->example);
        $this->assertNotNull(UserWord::where('user_id', $this->user->id)->where('word_id', $w->id)->value('introduced_at'));

        $this->postJson('/api/words/personal', ['word' => 'stove', 'translation' => 'estufa', 'example' => 'x'])->assertJsonPath('added', false);
        $this->postJson('/api/words/personal', ['word' => '<script>', 'translation' => 'x', 'example' => 'x'])->assertUnprocessable();

        // Otro alumno no la recibe como palabra nueva.
        $this->assertFalse(app(LevelService::class)->general()->where('id', $w->id)->exists());
    }
}
