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
                // Sin "pensar" antes de responder: estas tareas son cortas, y el pensamiento
                // se comía todos los tokens (respuesta vacía en las escenas AID).
                'thinking' => ['type' => 'disabled'],
                'system' => $system,
                'messages' => $messages,
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Error de la API de Claude: '.$response->status().' '.$response->json('error.message', ''));
        }

        $text = collect($response->json('content', []))
            ->where('type', 'text')
            ->pluck('text')
            ->implode("\n");

        if (trim($text) === '') {
            // Para diagnosticar respuestas vacías (p. ej. se acabaron los tokens antes del texto).
            \Illuminate\Support\Facades\Log::warning('Claude devolvió texto vacío', [
                'stop_reason' => $response->json('stop_reason'),
                'types' => collect($response->json('content', []))->pluck('type')->all(),
                'usage' => $response->json('usage'),
            ]);
        }

        return $text;
    }

    /** 3 escenas AID (acción irracional detallada) para una palabra. */
    public function suggestAid(string $word, string $translation): array
    {
        $system = 'Eres un profesor de inglés para hispanohablantes experto en mnemotecnia. '
            .'Usas la técnica AID (Acción Irracional Detallada) con el método de la palabra clave.';

        $prompt = <<<TXT
Palabra en inglés: "{$word}" (significa: {$translation}).
Crea 3 escenas AID MUY CORTAS en español para memorizarla de una sola vez.
Reglas para cada escena:
- Máximo 12 palabras en total.
- Empieza con una palabra en español que SUENE parecido a "{$word}", entre comillas, y dos puntos.
- Después, UNA sola imagen absurda y visual que una ese sonido con "{$translation}".
- Nada de listas de detalles ni frases largas: una imagen que se vea en un segundo.
Ejemplo para "clothes" (ropa): "Clocs": zuecos gigantes escupiendo ropa.
Responde solo con las 3 líneas, sin numeración ni texto extra.
TXT;

        $text = $this->message($system, [['role' => 'user', 'content' => $prompt]], 300);

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
    /**
     * Un turno de la conversación. $scenario es una de config('speaking.scenarios');
     * $voice = el alumno habla (lo que llega es una transcripción, sin puntuación fiable).
     *
     * @return array{reply: string, feedback: ?string, used: array<int, string>, mistakes: array<int, array{said: string, correct: string, why: ?string}>}
     */
    public function converse(array $history, array $targetWords, ?string $weakSounds = null, string $scenario = 'free', bool $voice = false, ?string $level = null): array
    {
        $words = implode(', ', $targetWords) ?: '(none)';
        $role = config("speaking.scenarios.{$scenario}.role") ?? config('speaking.scenarios.free.role');
        $level = $level ?: 'A2-B1';
        $input = $voice
            ? 'The student is SPEAKING: their messages are speech-to-text transcripts. Ignore punctuation, capitalization and spelling; correct only grammar, word choice and natural phrasing.'
            : 'The student is typing.';
        $system = <<<TXT
You are an English speaking partner for a Spanish-speaking adult (Latin American) who lives in Miami. Their level is about {$level} (CEFR).
Role-play: {$role}
Stay in character and keep the conversation going naturally. {$input}
Target words of the day (use them only when it fits naturally; praise the student when they use one): {$words}.
Rules:
- Keep each reply short (1-3 sentences, spoken style) and end with ONE question so the student keeps talking.
- Use simple, natural American English for their level. If the student seems lost, rephrase more simply.
- After your reply, add a line starting with "FEEDBACK:" written in Spanish: a short, encouraging note about the student's last message (max 2 sentences).
- Then, for each real mistake in the student's last message (max 2, skip tiny ones), add a line exactly like:
  FIX: <the student's words> => <the natural correct version> | <why, in Spanish, max 12 words>
- Then add a line starting with "USED:" listing the target words the student used correctly in their last message, comma separated (or "none").
TXT;
        if ($weakSounds) {
            $system .= "\nThe student struggles with these sounds: {$weakSounds}. Occasionally include words with them.";
        }

        // La API pide que el primer mensaje sea del alumno: si la IA abrió la conversación, va un saludo antes.
        if (empty($history) || ($history[0]['role'] ?? '') !== 'user') {
            array_unshift($history, ['role' => 'user', 'content' => 'Hi! Please start the conversation in character.']);
        }

        return self::parseTurn($this->message($system, $history, 600));
    }

    /** Separa la respuesta de la IA en: lo que dice, la nota en español, errores y palabras usadas. */
    public static function parseTurn(string $text): array
    {
        $feedback = null;
        $used = [];
        $mistakes = [];
        if (preg_match('/^FEEDBACK:\s*(.+)$/mi', $text, $m)) {
            $feedback = trim($m[1]);
        }
        if (preg_match('/^USED:\s*(.+)$/mi', $text, $m)) {
            $used = strtolower(trim($m[1])) === 'none' ? [] : array_values(array_filter(array_map('trim', explode(',', $m[1]))));
        }
        if (preg_match_all('/^FIX:\s*(.+?)\s*=>\s*(.+?)\s*(?:\|\s*(.+))?$/mi', $text, $all, PREG_SET_ORDER)) {
            foreach (array_slice($all, 0, 2) as $m) {
                $said = trim($m[1], " \t\"'“”");
                $correct = trim($m[2], " \t\"'“”");
                if ($said !== '' && $correct !== '' && mb_strtolower($said) !== mb_strtolower($correct)) {
                    $mistakes[] = ['said' => mb_substr($said, 0, 300), 'correct' => mb_substr($correct, 0, 300), 'why' => isset($m[3]) && trim($m[3]) !== '' ? mb_substr(trim($m[3]), 0, 300) : null];
                }
            }
        }
        $reply = trim(preg_replace(["/^(FEEDBACK|USED|FIX):.*$/mi", "/\n{3,}/"], ['', "\n\n"], $text));

        return ['reply' => $reply, 'feedback' => $feedback, 'used' => $used, 'mistakes' => $mistakes];
    }
}
