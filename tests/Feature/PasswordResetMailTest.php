<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PasswordResetMailTest extends TestCase
{
    use RefreshDatabase;

    public function test_reset_mail_is_in_spanish_and_links_to_the_app(): void
    {
        $user = User::factory()->create(['name' => 'Ana', 'email' => 'ana@example.com']);

        $html = (string) (new ResetPassword('tok123'))->toMail($user)->render();

        $this->assertStringContainsString('¡Hola, Ana!', $html);
        $this->assertStringContainsString('El equipo de W2W', $html);
        $this->assertStringContainsString('no funciona, copia y pega este enlace', $html);
        $this->assertStringContainsString('/app/?reset=tok123&amp;email=ana%40example.com', $html);
        $this->assertStringNotContainsString('Regards', $html);
        $this->assertStringNotContainsString("having trouble", $html);
    }

    public function test_app_mails_have_reply_to_support_when_configured(): void
    {
        config([
            'mail.default' => 'array',
            'mail.reply_to' => ['address' => 'soporte@huergalabs.dev', 'name' => 'Soporte de W2W'],
        ]);
        app()->forgetInstance('mail.manager');
        app()->forgetInstance('mailer');
        \Illuminate\Support\Facades\Mail::clearResolvedInstances();

        $user = User::factory()->create(['email' => 'ana@example.com']);
        $user->notify(new ResetPassword('tok'));

        $sent = app('mail.manager')->mailer('array')->getSymfonyTransport()->messages();
        $this->assertCount(1, $sent);
        $replyTo = $sent[0]->getOriginalMessage()->getReplyTo();
        $this->assertSame('soporte@huergalabs.dev', $replyTo[0]->getAddress());
    }
}
