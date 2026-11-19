<?php

namespace Tests\Feature;

use Tests\TestCase;

/** Página /prueba-micro: prueba de micrófono que se analiza en el navegador, sin enviar nada al servidor. */
class MicTestPageTest extends TestCase
{
    public function test_la_pagina_abre_sin_cuenta_y_con_cabeceras_estrictas(): void
    {
        $res = $this->get('/prueba-micro')->assertOk()
            ->assertSee('Prueba de micrófono')
            ->assertSee('name="robots" content="noindex"', false);

        $csp = (string) $res->headers->get('Content-Security-Policy');
        $this->assertStringContainsString("default-src 'none'", $csp);
        $this->assertStringContainsString("script-src 'self'", $csp);
        $this->assertStringContainsString("frame-ancestors 'none'", $csp);
        $this->assertStringNotContainsString('unsafe-inline', $csp);
        $this->assertStringNotContainsString('unsafe-eval', $csp);
        // Sin connect-src: con default-src 'none' la página no puede hacer peticiones a ningún sitio.
        $this->assertStringNotContainsString('connect-src', $csp);
        $this->assertSame('DENY', $res->headers->get('X-Frame-Options'));
        // El micrófono solo se permite a la propia web.
        $this->assertStringContainsString('microphone=(self)', (string) $res->headers->get('Permissions-Policy'));
    }

    public function test_sin_codigo_dentro_del_html(): void
    {
        $html = $this->get('/prueba-micro')->getContent();
        // Ni «onclick=» y compañía, ni scripts escritos dentro de la página: solo su archivo.
        $this->assertDoesNotMatchRegularExpression('/\son[a-z]+\s*=/i', $html);
        $this->assertSame(1, preg_match_all('/<script\b[^>]*>/i', $html, $tags));
        $this->assertMatchesRegularExpression('#<script src="/mic-test\.js\?v=\d+"></script>#', $html);
        $this->assertStringNotContainsString('style="', $html);
    }

    public function test_el_script_no_envia_nada_a_ningun_servidor(): void
    {
        $js = file_get_contents(public_path('mic-test.js'));
        foreach (['fetch(', 'XMLHttpRequest', 'sendBeacon', 'WebSocket', 'EventSource', 'MediaRecorder', 'innerHTML', 'eval('] as $forbidden) {
            $this->assertStringNotContainsString($forbidden, $js, "mic-test.js no debe usar $forbidden");
        }
        $this->assertFileExists(public_path('mic-test.css'));
    }
}
