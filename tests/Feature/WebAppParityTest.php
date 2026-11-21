<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * La web (public/app) tiene lo mismo que la app del teléfono: elegir curso y profesión en Ajustes, el mini-taller
 * de la palabra en «errores para repasar» y el manos libres que aguanta un error suelto del servidor.
 */
class WebAppParityTest extends TestCase
{
    private function file(string $name): string
    {
        return file_get_contents(public_path('app/'.$name));
    }

    public function test_cada_script_de_la_pagina_esta_en_la_cache_con_la_misma_version(): void
    {
        preg_match_all('#<script src="(/app/[a-z0-9-]+\.js\?v=\d+)"#', $this->file('index.html'), $m);
        $this->assertNotEmpty($m[1]);
        $sw = $this->file('sw.js');
        foreach ($m[1] as $src) {
            $this->assertStringContainsString('"'.$src.'"', $sw, "sw.js no guarda {$src} (o con otra versión)");
        }
    }

    public function test_ajustes_tiene_curso_profesion_y_mini_taller(): void
    {
        $html = $this->file('index.html');
        foreach (['id="courseBox"', 'id="profBox"', 'id="wordDrillOn"', '/app/account.js', '/app/worddrill.js'] as $needle) {
            $this->assertStringContainsString($needle, $html);
        }
        $account = $this->file('account.js');
        foreach (['"/courses"', '"/course"', '"/professions"', '"/profile"'] as $endpoint) {
            $this->assertStringContainsString($endpoint, $account);
        }
        // Sin onclick= (CSP): los botones usan data-acct.
        $this->assertStringNotContainsString('onclick=', $account);
    }

    public function test_mini_taller_usa_los_mismos_umbrales_que_la_app(): void
    {
        $js = $this->file('worddrill.js');
        $dart = file_get_contents(base_path('mobile/lib/core/utils/word_drill.dart'));
        preg_match('/drillMaxAccuracy = (\d+)/', $dart, $max);
        preg_match('/drillPassScore = (\d+)/', $dart, $pass);
        preg_match('/drillTries = (\d+)/', $dart, $tries);
        $this->assertStringContainsString("MAX: {$max[1]}, PASS: {$pass[1]}, TRIES: {$tries[1]}", $js);
    }

    public function test_manos_libres_de_errores_reintenta_un_error_suelto(): void
    {
        $js = $this->file('speak.js');
        $this->assertStringContainsString('Sorry, something went wrong. Try again.', $js);
        $this->assertStringContainsString('++rv.errs >= 2', $js);
    }

    public function test_brainy_esta_en_la_web(): void
    {
        $html = $this->file('index.html');
        foreach (['id="petView"', 'id="petSettings"', '/app/pet-draw.js', '/app/pet.js'] as $needle) {
            $this->assertStringContainsString($needle, $html);
        }
        $js = $this->file('pet.js');
        foreach (['"/pet"', '"/pet/name"', '"/pet/color"', '"/pet/" + a', '"/experiments/brainy"'] as $endpoint) {
            $this->assertStringContainsString($endpoint, $js);
        }
        // Los 4 botones de cuidado son los que acepta la ruta POST /pet/{action}.
        foreach (['feed', 'play', 'clean', 'medicine'] as $action) {
            $this->assertMatchesRegularExpression('/\["'.$action.'", "/', $js);
        }
        $this->assertStringNotContainsString('onclick=', $js);
    }

    public function test_los_colores_de_brainy_son_los_del_servidor(): void
    {
        preg_match_all("/^\\s*\\['([a-z]+)', '/m", $this->file('pet-draw.js'), $m);
        $this->assertSame(\App\Services\PetService::COLORS, $m[1]);
    }

    public function test_los_textos_nuevos_tienen_traduccion_al_ingles(): void
    {
        $en = json_decode(file_get_contents(base_path('lang/en.json')), true);
        foreach (['Qué aprendes', 'Tu trabajo', '¿A qué te dedicas?', '¿Para qué quieres el inglés?', 'Practiquemos una palabra',
            '1. La palabra sola', '2. En su trozo de frase', '3. Ahora la frase completa', 'Decir la frase completa',
            'Practicar la palabra que fallo', 'En construcción (solo para probar)'] as $text) {
            $this->assertArrayHasKey($text, $en, "Falta en lang/en.json: «{$text}»");
        }
    }
}
