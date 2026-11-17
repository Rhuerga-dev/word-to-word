<?php

namespace Tests\Feature;

use App\Services\ClaudeService;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Tests\TestCase;

/**
 * Regla: la evaluación EN VIVO (un alumno esperando) corta antes y SIN reintentos,
 * para que el peor caso no llegue a ~3 minutos. Los lotes de noche sí reintentan.
 */
class ClaudeLiveTest extends TestCase
{
    /** Sin gateway: las llamadas van directas al API de Claude, que es donde está el reintento. */
    private function useDirectApi(): void
    {
        config([
            'vocab.ai_gateway.key' => null,
            'vocab.anthropic.key' => 'test-key',
            'vocab.anthropic.model' => 'claude-test',
            'vocab.anthropic.version' => '2023-06-01',
        ]);
        Http::fake(['api.anthropic.com/*' => Http::response(['error' => ['message' => 'boom']], 500)]);
    }

    public function test_una_llamada_en_vivo_no_reintenta(): void
    {
        $this->useDirectApi();

        $threw = false;
        try {
            // gradeConversation califica la prueba de unidad mientras el alumno espera: es "en vivo".
            (new ClaudeService)->gradeConversation([['role' => 'user', 'content' => 'hi']], 'una tienda', 'A2');
        } catch (RuntimeException) {
            $threw = true;
        }

        $this->assertTrue($threw, 'debería fallar al 500');
        Http::assertSentCount(1);   // un solo intento, sin reintentos
    }

    public function test_un_lote_de_noche_si_reintenta(): void
    {
        $this->useDirectApi();

        $threw = false;
        try {
            // define() es trabajo de lote (de noche): sí espera y reintenta.
            (new ClaudeService)->define(['borrow']);
        } catch (RuntimeException) {
            $threw = true;
        }

        $this->assertTrue($threw, 'debería fallar al 500');
        Http::assertSentCount(2);   // retry(2) = 2 intentos en total (1 + 1 reintento)
    }
}
