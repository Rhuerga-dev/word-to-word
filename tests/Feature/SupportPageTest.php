<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use Tests\TestCase;

/** Página /apoyo («Apoya mi desarrollo con un café»): datos del .env, solo en la web y nunca en la app. */
class SupportPageTest extends TestCase
{
    use RefreshDatabase;

    public function test_sin_datos_la_pagina_no_existe_y_la_web_no_ensena_el_enlace(): void
    {
        config(['vocab.support.zelle' => null, 'vocab.support.paypal_url' => '']);
        $this->get('/apoyo')->assertNotFound();
        $this->getJson('/api/config')->assertOk()->assertJsonPath('support', false);
    }

    public function test_ensena_zelle_y_paypal_con_cabeceras_estrictas(): void
    {
        config(['vocab.support.zelle' => 'cafe@example.com', 'vocab.support.paypal_url' => 'https://paypal.me/ejemplo']);
        $res = $this->get('/apoyo')->assertOk()
            ->assertSee('Apoya mi desarrollo con un café')
            ->assertSee('cafe@example.com')
            ->assertSee('href="https://paypal.me/ejemplo"', false)
            ->assertSee('rel="noopener noreferrer"', false)
            ->assertDontSee('<script', false);
        // Se llama «apoyo», no «donación».
        $this->assertStringNotContainsStringIgnoringCase('donaci', $res->getContent());
        $this->assertStringNotContainsStringIgnoringCase('donat', $res->getContent());

        $csp = (string) $res->headers->get('Content-Security-Policy');
        $this->assertStringContainsString("default-src 'none'", $csp);
        $this->assertStringContainsString("frame-ancestors 'none'", $csp);
        $this->assertStringNotContainsString('unsafe-inline', $csp);
        $this->assertSame('DENY', $res->headers->get('X-Frame-Options'));

        $this->getJson('/api/config')->assertJsonPath('support', true);
    }

    public function test_con_solo_uno_de_los_dos_ensena_solo_ese(): void
    {
        config(['vocab.support.zelle' => '+1 305 555 0100', 'vocab.support.paypal_url' => null]);
        $this->get('/apoyo')->assertOk()->assertSee('+1 305 555 0100')->assertDontSee('PayPal');

        config(['vocab.support.zelle' => '', 'vocab.support.paypal_url' => 'https://www.paypal.com/paypalme/ejemplo']);
        $this->get('/apoyo')->assertOk()->assertSee('PayPal')->assertDontSee('Zelle');
    }

    public function test_el_dato_de_zelle_sale_escapado(): void
    {
        config(['vocab.support.zelle' => '<img src=x onerror=alert(1)>', 'vocab.support.paypal_url' => null]);
        $this->get('/apoyo')->assertOk()->assertDontSee('<img src=x', false)->assertSee('&lt;img src=x', false);
    }

    public function test_un_enlace_que_no_es_de_paypal_no_se_usa(): void
    {
        foreach (['http://paypal.me/x', 'https://paypal.me.evil.example/x', 'javascript:alert(1)', 'https://evil.example/paypal.me',
            'https://user@paypal.me/x', 'paypal.me/x'] as $url) {
            config(['vocab.support.zelle' => null, 'vocab.support.paypal_url' => $url]);
            $this->get('/apoyo')->assertNotFound();
        }
    }

    /** Política de pagos de Google Play: la app de Android no enlaza a la página de apoyo ni menciona pagos. */
    public function test_la_app_flutter_no_enlaza_a_apoyo(): void
    {
        foreach (File::allFiles(base_path('mobile/lib')) as $file) {
            $code = strtolower($file->getContents());
            foreach (['/apoyo', 'paypal', 'zelle', 'apoya mi desarrollo'] as $word) {
                $this->assertStringNotContainsString($word, $code, $file->getRelativePathname().' menciona «'.$word.'»');
            }
        }
    }
}
