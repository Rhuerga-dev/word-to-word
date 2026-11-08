<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Auth\Notifications\VerifyEmail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\URL;
use Tests\TestCase;

class AccountTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_creates_unverified_account_and_sends_verification_email(): void
    {
        Notification::fake();

        $res = $this->postJson('/api/auth/register', [
            'name' => 'Rey',
            'email' => 'rey@example.com',
            'password' => 'secret-pass-123',
            'timezone' => 'America/New_York',
        ])->assertCreated();

        $res->assertJsonPath('user.email_verified', false)
            ->assertJsonPath('user.cefr_level', null)
            ->assertJsonStructure(['token']);

        $user = User::whereEmail('rey@example.com')->firstOrFail();
        Notification::assertSentTo($user, VerifyEmail::class);
    }

    public function test_verification_link_marks_email_as_verified(): void
    {
        $user = User::factory()->unverified()->create();
        $url = URL::temporarySignedRoute('verification.verify', now()->addHour(), [
            'id' => $user->id,
            'hash' => sha1($user->email),
        ]);

        $this->get($url)->assertRedirect(url('/app').'/?verified=1');
        $this->assertTrue($user->fresh()->hasVerifiedEmail());
    }

    public function test_verification_link_with_wrong_hash_is_rejected(): void
    {
        $user = User::factory()->unverified()->create();
        $url = URL::temporarySignedRoute('verification.verify', now()->addHour(), [
            'id' => $user->id,
            'hash' => sha1('someone-else@example.com'),
        ]);

        $this->get($url)->assertForbidden();
        $this->assertFalse($user->fresh()->hasVerifiedEmail());
    }

    public function test_unsigned_verification_link_is_rejected(): void
    {
        $user = User::factory()->unverified()->create();

        $this->get("/email/verify/{$user->id}/".sha1($user->email))->assertForbidden();
    }

    public function test_forgot_password_sends_a_link_to_the_app(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'rey@example.com']);

        $this->postJson('/api/auth/forgot-password', ['email' => 'rey@example.com'])->assertOk();

        Notification::assertSentTo($user, ResetPassword::class, function (ResetPassword $n) use ($user) {
            $mail = $n->toMail($user);

            return str_contains($mail->actionUrl, '/app/?reset=')
                && str_contains($mail->actionUrl, 'email='.urlencode($user->email));
        });
    }

    public function test_forgot_password_does_not_reveal_unknown_emails(): void
    {
        Notification::fake();
        User::factory()->create(['email' => 'rey@example.com']);

        $known = $this->postJson('/api/auth/forgot-password', ['email' => 'rey@example.com'])->json('message');
        $unknown = $this->postJson('/api/auth/forgot-password', ['email' => 'nobody@example.com'])->json('message');

        $this->assertSame($known, $unknown);
    }

    public function test_reset_password_changes_it_and_signs_out_everywhere(): void
    {
        $user = User::factory()->unverified()->create(['email' => 'rey@example.com']);
        $user->createToken('old-device');
        $token = Password::createToken($user);

        $this->postJson('/api/auth/reset-password', [
            'token' => $token,
            'email' => 'rey@example.com',
            'password' => 'new-secret-1',
            'password_confirmation' => 'new-secret-1',
        ])->assertOk();

        $user->refresh();
        $this->assertTrue(Hash::check('new-secret-1', $user->password));
        $this->assertSame(0, $user->tokens()->count());
        $this->assertTrue($user->hasVerifiedEmail());

        $this->postJson('/api/auth/login', ['email' => 'rey@example.com', 'password' => 'new-secret-1'])->assertOk();
    }

    public function test_reset_password_with_invalid_token_fails(): void
    {
        User::factory()->create(['email' => 'rey@example.com']);

        $this->postJson('/api/auth/reset-password', [
            'token' => 'not-a-real-token',
            'email' => 'rey@example.com',
            'password' => 'new-secret-1',
            'password_confirmation' => 'new-secret-1',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_resend_verification_email(): void
    {
        Notification::fake();
        $user = User::factory()->unverified()->create();

        $this->actingAs($user)->postJson('/api/email/verification-notification')->assertOk();

        Notification::assertSentTo($user, VerifyEmail::class);
    }
}
