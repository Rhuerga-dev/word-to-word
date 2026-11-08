<?php

namespace Tests\Feature;

use Tests\TestCase;

/** Las respuestas de Laravel llevan cabeceras de seguridad y no anuncian la versión de PHP. */
class SecurityHeadersTest extends TestCase
{
    public function test_laravel_responses_carry_security_headers(): void
    {
        $res = $this->get('/up')->assertOk()
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin')
            ->assertHeaderMissing('X-Powered-By');

        $this->assertStringContainsString("frame-ancestors 'none'", $res->headers->get('Content-Security-Policy'));
    }

    public function test_the_static_app_has_no_inline_script(): void
    {
        $html = file_get_contents(public_path('app/index.html'));

        $this->assertDoesNotMatchRegularExpression('/<script(?![^>]*\ssrc=)[^>]*>/', $html);
        $this->assertDoesNotMatchRegularExpression('/\son(click|change|input|submit|load)=/i', $html);
        $this->assertFileExists(public_path('app/app.js'));
    }
}
