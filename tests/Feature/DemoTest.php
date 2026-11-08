<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\DemoService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class DemoTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Nunca llamar a Claude ni a Azure de verdad desde las pruebas.
        Http::fake(['*' => Http::response(['content' => [['type' => 'text', 'text' => 'ok']]], 200)]);
        for ($i = 1; $i <= 60; $i++) {
            Word::create(['word' => 'word'.$i, 'rank' => $i, 'source' => 'ngsl', 'translation' => 'palabra '.$i, 'example' => 'A *word'.$i.'* here.']);
        }
    }

    private function startDemo(): array
    {
        return $this->postJson('/api/auth/demo')->assertCreated()->json();
    }

    public function test_demo_creates_a_private_sample_student_with_history(): void
    {
        $r = $this->startDemo();

        $this->assertTrue($r['user']['demo']);
        $this->assertSame('B1', $r['user']['cefr_level']);
        $this->assertTrue($r['user']['email_verified']);

        $user = User::where('email', $r['user']['email'])->firstOrFail();
        $this->assertSame(60, UserWord::where('user_id', $user->id)->count());
        $this->assertGreaterThan(0, UserWord::where('user_id', $user->id)->whereDate('next_review', '<=', today())->count());

        $this->withToken($r['token'])->getJson('/api/today')->assertOk();
        // Estudió ayer (en la zona horaria de la app): la racha sigue viva.
        $this->withToken($r['token'])->getJson('/api/stats')->assertOk()->assertJsonPath('streak', 12);
        $this->withToken($r['token'])->getJson('/api/me')->assertOk()->assertJsonPath('demo', true);
    }

    public function test_each_visitor_gets_their_own_student(): void
    {
        $a = $this->startDemo();
        $b = $this->startDemo();

        $this->assertNotSame($a['user']['email'], $b['user']['email']);
        $this->assertSame(2, User::where('email', 'like', '%@'.DemoService::DOMAIN)->count());
    }

    public function test_demo_sends_no_emails_or_push(): void
    {
        $r = $this->startDemo();

        $this->withToken($r['token'])->postJson('/api/email/verification-notification')->assertForbidden()->assertJsonPath('demo', true);
        $this->withToken($r['token'])->postJson('/api/push/subscriptions', ['endpoint' => 'https://x'])->assertForbidden();
        $this->withToken($r['token'])->putJson('/api/reminders', ['enabled' => true])->assertForbidden();
    }

    public function test_paid_features_have_a_daily_allowance(): void
    {
        $r = $this->startDemo();

        for ($i = 0; $i < DemoGuardLimits::CONVERSATION; $i++) {
            $this->withToken($r['token'])->postJson('/api/conversation', ['messages' => []]);
        }
        $this->withToken($r['token'])->postJson('/api/conversation', ['messages' => []])->assertStatus(429);
    }

    public function test_old_demo_students_are_deleted(): void
    {
        $old = $this->startDemo();
        User::where('email', $old['user']['email'])->update(['created_at' => now()->subHours(25)]);

        $this->startDemo();

        $this->assertNull(User::where('email', $old['user']['email'])->first());
        $this->assertSame(1, User::where('email', 'like', '%@'.DemoService::DOMAIN)->count());
    }

    public function test_real_users_are_not_limited(): void
    {
        $user = User::factory()->create();
        $this->assertFalse(DemoService::isDemo($user));
        $this->actingAs($user, 'sanctum')->getJson('/api/me')->assertOk()->assertJsonPath('demo', false);
    }
}

/** Kept here so the test reads clearly. */
final class DemoGuardLimits
{
    public const CONVERSATION = \App\Http\Middleware\DemoGuard::QUOTAS['api/conversation'];
}
