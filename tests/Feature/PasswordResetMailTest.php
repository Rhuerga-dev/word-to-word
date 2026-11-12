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
}
