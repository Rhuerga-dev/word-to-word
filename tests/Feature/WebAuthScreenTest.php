<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * La pantalla de entrar de la web: al pedir el enlace de contraseña cambia a «Revisa tu correo»
 * (antes se quedaba igual y parecía que no había pasado nada), y pide la misma contraseña que el servidor.
 */
class WebAuthScreenTest extends TestCase
{
    private function shell(string $file): string
    {
        return (string) file_get_contents(public_path("app/{$file}"));
    }

    public function test_after_asking_for_the_link_there_is_a_check_your_email_screen(): void
    {
        $html = $this->shell('index.html');
        $js = $this->shell('app.js');

        $this->assertStringContainsString('id="authSent"', $html);
        $this->assertStringContainsString('No hay ningún código que escribir', $html);
        $this->assertStringContainsString('sent: "Revisa tu correo"', $js);
        $this->assertStringContainsString('setAuthMode("sent")', $js);
        // El mensaje no confirma si el correo existe (misma respuesta exista o no la cuenta).
        $this->assertStringContainsString('"Si " + email + " tiene una cuenta', $js);
    }

    public function test_the_web_asks_for_the_same_password_as_the_server(): void
    {
        $js = $this->shell('app.js');

        $this->assertStringContainsString('al menos 10 caracteres, con letras y números', $js);
        $this->assertStringNotContainsString('al menos 8 caracteres', $js);
    }

    public function test_the_page_and_the_offline_cache_ask_for_the_same_script_version(): void
    {
        preg_match('#/app/app\.js\?v=(\d+)#', $this->shell('index.html'), $page);
        preg_match('#/app/app\.js\?v=(\d+)#', $this->shell('sw.js'), $cache);

        $this->assertNotEmpty($page[1] ?? null);
        $this->assertSame($page[1], $cache[1] ?? null, 'index.html y sw.js piden versiones distintas de app.js');
    }
}
