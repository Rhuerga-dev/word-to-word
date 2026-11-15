<?php

namespace Tests\Feature;

use App\Models\InvitationCode;
use App\Models\User;
use App\Services\InviteService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

/** Registro solo con código de invitación (los crea Reynaldo desde el panel con `invites`). */
class InviteTest extends TestCase
{
    use RefreshDatabase;

    private function register(string $email, ?string $invite)
    {
        return $this->postJson('/api/auth/register', array_filter([
            'name' => 'Alumno', 'email' => $email, 'password' => 'secret-pass-123', 'invite' => $invite,
        ]));
    }

    protected function setUp(): void
    {
        parent::setUp();
        Notification::fake();
    }

    public function test_without_a_code_you_cannot_register(): void
    {
        $this->register('a@example.com', null)->assertUnprocessable()->assertJsonValidationErrors('invite');
        $this->assertSame(0, User::count());
    }

    public function test_a_code_works_until_it_runs_out_and_marks_who_used_it(): void
    {
        $inv = app(InviteService::class)->create(2, null, 'Familia', 'FAMILIA');

        $this->register('a@example.com', ' familia ')->assertCreated();
        $this->register('b@example.com', 'FAMILIA')->assertCreated();
        $this->register('c@example.com', 'FAMILIA')->assertUnprocessable()->assertJsonPath('errors.invite.0', 'Código de invitación no válido.');

        $this->assertSame(2, $inv->fresh()->used);
        $this->assertSame($inv->id, User::whereEmail('a@example.com')->value('invitation_code_id'));
    }

    public function test_unknown_expired_and_disabled_codes_get_the_same_message(): void
    {
        $svc = app(InviteService::class);
        $svc->create(5, 1, null, 'CADUCA');
        $svc->create(5, null, null, 'APAGADO');
        $svc->disable('apagado');
        $this->travel(2)->days();

        foreach (['NOEXISTE', 'CADUCA', 'APAGADO'] as $code) {
            $this->register(strtolower($code).'@example.com', $code)->assertUnprocessable()
                ->assertJsonPath('errors.invite.0', 'Código de invitación no válido.');
        }
    }

    public function test_a_failed_signup_does_not_spend_the_code(): void
    {
        $inv = app(InviteService::class)->create(1, null, null, 'UNICO');
        User::factory()->create(['email' => 'ya@example.com']);

        $this->register('ya@example.com', 'UNICO')->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->assertSame(0, $inv->fresh()->used);
        $this->register('nuevo@example.com', 'UNICO')->assertCreated();
    }

    public function test_registration_can_be_opened_by_config_and_the_apps_know_it(): void
    {
        $this->getJson('/api/config')->assertJsonPath('invite_required', true);
        config(['vocab.invites_required' => false]);
        $this->getJson('/api/config')->assertJsonPath('invite_required', false);
        $this->register('libre@example.com', null)->assertCreated();
    }

    public function test_the_panel_command_creates_lists_and_disables_codes_in_json(): void
    {
        $this->artisan('invites', ['action' => 'create', '--uses' => 10, '--days' => 30, '--note' => 'Amigos'])->assertSuccessful();
        $code = InvitationCode::first();
        $this->assertMatchesRegularExpression('/^W2W-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/', $code->code);
        $this->assertSame(10, $code->max_uses);

        $this->artisan('invites', ['action' => 'list'])->expectsOutputToContain('"code":"'.$code->code.'"')->assertSuccessful();
        $this->artisan('invites', ['action' => 'disable', 'code' => $code->code])->expectsOutputToContain('"active":false')->assertSuccessful();
        $this->artisan('invites', ['action' => 'create', '--uses' => 0])->expectsOutputToContain('"ok":false')->assertFailed();
        $this->artisan('invites', ['action' => 'create', '--code' => 'mal código!'])->assertFailed();
        $this->artisan('invites', ['action' => 'disable', 'code' => 'NOEXISTE'])->assertFailed();
    }
}
