<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Llamadas a la API de Claude (Anthropic) desde el servidor.
 * La clave vive en .env y nunca llega al navegador.
 */
class ClaudeService
{
    public function enabled(): bool
    {
        return filled(config('vocab.anthropic.key'));
    }

    /**
     * @param  array<int, array{role: string, content: string}>  $messages
     */
    public function message(string $system, array $messages, int $maxTokens = 800): string
    {
        if (! $this->enabled()) {
            throw new RuntimeException('Falta ANTHROPIC_API_KEY en el archivo .env');
        }

        $response = Http::withHeaders([
            'x-api-key' => config('vocab.anthropic.key'),
            'anthropic-version' => config('vocab.anthropic.version'),
        ])
            ->timeout(60)
            ->retry(2, 1500, throw: false)
            ->post('https://api.anthropic.com/v1/messages', [
                'model' => config('vocab.anthropic.model'),
                'max_tokens' => $maxTokens,
                'system' => $system,
                'messages' => $messages,
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Error de la API de Claude: '.$response->status().' '.$response->json('error.message', ''));
        }

        return collect($response->json('content', []))
            ->where('type', 'text')
            ->pluck('text')
            ->implode("\n");
    }

    /** 3 escenas AID (acción irracional detallada) para una palabra. */
    public function suggestAid(string $word, string $translation): array
    {
        $system = 'Eres un profesor de inglés para hispanohablantes experto en mnemotecnia. '
            .'Usas la técnica AID (Acción Irracional Detallada) con el método de la palabra clave.';

        $prompt = <<<TXT
Palabra en inglés: "{$word}" (significa: {$translation}).
Crea 3 escenas distintas, cada una en UNA línea en español, de máximo 30 palabras:
1) empieza con una palabra o frase en español que SUENE parecido a "{$word}", entre comillas;
2) describe una acción absurda, exagerada y con detalles visuales (colores, ruido, movimiento)
   que una ese sonido con el significado "{$translation}".
Responde solo con las 3 líneas, sin numeración ni texto extra.
TXT;

        $text = $this->message($system, [['role' => 'user', 'content' => $prompt]], 400);

        return collect(preg_split('/\R/', $text))
            ->map(fn ($l) => trim(preg_replace('/^\s*[-*\d.)]+\s*/', '', $l)))
            ->filter()
            ->take(3)
            ->values()
            ->all();
    }

    /**
     * Traducción y ejemplo para un lote de palabras (usado por words:enrich).
     *
     * @param  string[]  $words
     * @return array<string, array{translation: string, example: string, example_es: string}>
     */
    public function enrich(array $words): array
    {
        $list = implode("\n", $words);
        $system = 'Eres un lexicógrafo bilingüe inglés-español (español latinoamericano neutro).';
        $prompt = <<<TXT
Para cada palabra en inglés de la lista, devuelve:
- "translation": 1 a 3 traducciones al español más comunes, separadas por "; "
- "example": una oración corta y cotidiana en inglés (máx. 10 palabras) que use la palabra, con la palabra entre *asteriscos*
- "example_es": la traducción natural de esa oración

Responde SOLO con un objeto JSON cuyo clave sea cada palabra exactamente como aparece.
Ejemplo: {"borrow": {"translation": "pedir prestado", "example": "Can I *borrow* your pen?", "example_es": "¿Me prestas tu bolígrafo?"}}

Palabras:
{$list}
TXT;

        $text = $this->message($system, [['role' => 'user', 'content' => $prompt]], 4000);
        $start = strpos($text, '{');
        $end = strrpos($text, '}');
        if ($start === false || $end === false) {
            throw new RuntimeException('La respuesta no traía JSON.');
        }
        $data = json_decode(substr($text, $start, $end - $start + 1), true);
        if (! is_array($data)) {
            throw new RuntimeException('JSON inválido en la respuesta.');
        }

        return $data;
    }

    /**
     * Conversación de práctica que obliga a usar las palabras del día.
     *
     * @param  array<int, array{role: string, content: string}>  $history
     * @param  string[]  $targetWords
     */
    public function converse(array $history, array $targetWords, ?string $weakSounds = null): array
    {
        $words = implode(', ', $targetWords);
        $system = <<<TXT
You are a friendly English conversation tutor for a Spanish-speaking adult (Latin American) who lives in Miami.
Goal: get the student to USE these target words naturally: {$words}.
Rules:
- Keep each reply short (1-3 sentences) and end with ONE question that invites the student to use a target word they have not used yet.
- Speak simple, natural American English.
- After your reply, add a line starting with "FEEDBACK:" written in Spanish: correct the student's last message (grammar, word choice, more natural phrasing). If it was correct, say what was good. Max 2 short sentences.
- Then add a line starting with "USED:" listing the target words the student used correctly in their last message, comma separated (or "none").
TXT;
        if ($weakSounds) {
            $system .= "\nThe student struggles with these sounds: {$weakSounds}. Occasionally include words with them.";
        }

        if (empty($history)) {
            $history = [['role' => 'user', 'content' => 'Hi! Let\'s start.']];
        }

        $text = $this->message($system, $history, 500);

        $reply = $text;
        $feedback = null;
        $used = [];
        if (preg_match('/^FEEDBACK:\s*(.+)$/mi', $text, $m)) {
            $feedback = trim($m[1]);
        }
        if (preg_match('/^USED:\s*(.+)$/mi', $text, $m)) {
            $used = strtolower(trim($m[1])) === 'none' ? [] : array_map('trim', explode(',', $m[1]));
        }
        $reply = trim(preg_replace('/^(FEEDBACK|USED):.*$/mi', '', $reply));

        return ['reply' => $reply, 'feedback' => $feedback, 'used' => $used];
    }
}
