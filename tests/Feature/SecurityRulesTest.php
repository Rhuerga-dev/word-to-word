<?php

namespace Tests\Feature;

use App\Http\Middleware\DemoGuard;
use App\Models\User;
use App\Services\DemoService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Reglas de la auditoría: push solo a servicios reales, demo reservada, sin "adelantar día", límites diarios. */
class SecurityRulesTest extends TestCase
{
    use RefreshDatabase;

    public function test_push_subscriptions_only_accept_real_push_services(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $keys = ['p256dh' => 'k', 'auth' => 'a'];

        foreach (['http://fcm.googleapis.com/fcm/send/x', 'https://127.0.0.1/x', 'https://evil.example.com/x', 'https://fcm.googleapis.com.evil.com/x'] as $bad) {
            $this->postJson('/api/push/subscriptions', ['endpoint' => $bad, 'keys' => $keys])->assertUnprocessable();
        }
        $this->postJson('/api/push/subscriptions', ['endpoint' => 'https://fcm.googleapis.com/fcm/send/abc', 'keys' => $keys])->assertNoContent();
    }

    public function test_nobody_can_register_with_the_demo_domain(): void
    {
        $this->postJson('/api/auth/register', [
            'name' => 'X', 'email' => 'yo@'.DemoService::DOMAIN, 'password' => 'clave-segura-123',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_time_travel_is_off_by_default(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/debug/next-day')->assertForbidden();
    }

    public function test_paid_features_have_a_daily_limit_per_user(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $day = now()->toDateString();
        cache()->put("paid:{$day}:{$user->id}:api/conversation", DemoGuard::USER_DAILY['api/conversation'], now()->addDay());

        $this->postJson('/api/conversation', ['message' => 'hola'])->assertStatus(429);
    }

    public function test_unverified_accounts_get_half_the_daily_allowance(): void
    {
        $user = User::factory()->unverified()->create();
        Sanctum::actingAs($user);
        cache()->put('paid:'.now()->toDateString().":{$user->id}:api/conversation", (int) ceil(DemoGuard::USER_DAILY['api/conversation'] / 2), now()->addDay());

        $this->postJson('/api/conversation', ['messages' => []])->assertStatus(429);
    }

    public function test_demo_sessions_count_against_the_global_daily_cap(): void
    {
        $token = $this->postJson('/api/auth/demo')->assertCreated()->json('token');
        cache()->put('paid:'.now()->toDateString().':all:api/conversation', DemoGuard::GLOBAL_DAILY['api/conversation'], now()->addDay());

        $this->withToken($token)->postJson('/api/conversation', ['messages' => []])->assertStatus(429);
    }

    public function test_login_takes_a_password_hash_even_for_unknown_emails_and_says_the_same(): void
    {
        User::factory()->create(['email' => 'existe@example.com', 'password' => 'clave-segura-123']);
        $a = $this->postJson('/api/auth/login', ['email' => 'nadie@example.com', 'password' => 'mala-clave-1'])->assertUnprocessable();
        $b = $this->postJson('/api/auth/login', ['email' => 'existe@example.com', 'password' => 'mala-clave-1'])->assertUnprocessable();
        $this->assertSame($a->json('errors'), $b->json('errors'));
    }

    public function test_new_passwords_need_letters_numbers_and_ten_characters(): void
    {
        $this->postJson('/api/auth/register', ['name' => 'X', 'email' => 'nuevo@example.com', 'password' => 'solo-letras'])
            ->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_tts_prune_keeps_the_cache_under_the_limit(): void
    {
        \Illuminate\Support\Facades\Storage::fake('local');
        $disk = \Illuminate\Support\Facades\Storage::disk('local');
        $disk->put('tts/viejo.mp3', 'x');
        touch($disk->path('tts/viejo.mp3'), now()->subDays(90)->getTimestamp());
        $disk->put('tts/nuevo.mp3', 'x');

        $this->artisan('tts:prune')->assertSuccessful();

        $disk->assertMissing('tts/viejo.mp3');
        $disk->assertExists('tts/nuevo.mp3');
    }

    public function test_reiniciar_progreso_pide_la_contrasena(): void
    {
        $user = \App\Models\User::factory()->create(['xp_total' => 50]);
        \Laravel\Sanctum\Sanctum::actingAs($user);

        $this->postJson('/api/reset')->assertStatus(422)->assertJsonValidationErrors('password');
        $this->postJson('/api/reset', ['password' => 'otra-cosa'])->assertStatus(422);
        $this->assertSame(50, $user->fresh()->xp_total);

        $this->postJson('/api/reset', ['password' => 'password'])->assertNoContent();
        $this->assertSame(0, $user->fresh()->xp_total);
    }
}
