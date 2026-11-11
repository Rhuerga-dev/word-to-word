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
    /** Idioma de las explicaciones al alumno: es · simple (inglés sencillo) · en (escalera de español). */
    private string $lang = 'es';

    public function explainIn(string $lang): static
    {
        $this->lang = in_array($lang, ['es', 'simple', 'en'], true) ? $lang : 'es';

        return $this;
    }

    private function inLang(): string
    {
        return match ($this->lang) {
            'simple' => 'in very simple English (short sentences, common words)',
            'en' => 'in English',
            default => 'in Spanish',
        };
    }

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
     * Definiciones sencillas en inglés (de diccionario para estudiantes), sin usar la propia palabra.
     *
     * @param  string[]  $words
     * @return array<string, string>
     */
    public function define(array $words): array
    {
        $list = implode("\n", $words);
        $prompt = <<<TXT
For each English word below, write a short learner's dictionary definition in simple English (max 12 words).
Do NOT use the word itself or any form of it. Use the most common meaning.
Answer ONLY with a JSON object: {"word": "definition", ...}, keys exactly as given.
Example: {"borrow": "to take something from someone and give it back later"}

Words:
{$list}
TXT;
        $text = $this->message('You write clear, simple definitions for English learners.', [['role' => 'user', 'content' => $prompt]], 3000);
        $start = strpos($text, '{');
        $end = strrpos($text, '}');
        $data = $start !== false && $end !== false ? json_decode(substr($text, $start, $end - $start + 1), true) : null;
        if (! is_array($data)) {
            throw new RuntimeException('La respuesta no traía JSON válido.');
        }

        return array_filter(array_map(fn ($d) => is_string($d) ? trim($d) : null, $data));
    }

    /**
     * Significados fáciles para reconocer palabras de oído, de menos a más difícil:
     * gloss (1–3 palabras muy básicas), emoji (si lo muestra claro) y una definición con palabras muy comunes.
     *
     * @param  array<int, string>  $words
     * @return array<string, array{gloss: ?string, emoji: ?string, easy: ?string, phrase: ?string, long: ?string}>
     */
    public function simplify(array $words): array
    {
        $list = implode("\n", $words);
        $prompt = <<<TXT
For each English word below, help a beginner who does NOT know much English understand it.
Give:
- "gloss": 1 to 3 VERY simple English words that show the meaning (like "last day", "paper with price", "money for a house"). A1 level only.
- "emoji": ONE emoji only if it shows the meaning clearly; otherwise null.
- "easy": a definition of max 10 words using ONLY the 1000 most common English words.
- "phrase": a very common short phrase of 2 to 5 words that CONTAINS the word (like "pay the rent", "meet the deadline").
- "long": one natural spoken sentence of 12 to 18 words that CONTAINS the word, with simple everyday vocabulary.
In gloss, emoji and easy never use the word itself or any form of it. Use the most common meaning.
Answer ONLY with a JSON object: {"word": {"gloss": "...", "emoji": "..." or null, "easy": "...", "phrase": "...", "long": "..."}, ...}, keys exactly as given.

Words:
{$list}
TXT;
        $text = $this->message('You explain English words with the simplest possible English.', [['role' => 'user', 'content' => $prompt]], 4000);
        $start = strpos($text, '{');
        $end = strrpos($text, '}');
        $data = $start !== false && $end !== false ? json_decode(substr($text, $start, $end - $start + 1), true) : null;
        if (! is_array($data)) {
            throw new RuntimeException('La respuesta no traía JSON válido.');
        }
        $out = [];
        foreach ($data as $word => $m) {
            if (is_array($m)) {
                $out[$word] = [
                    'gloss' => is_string($m['gloss'] ?? null) ? trim($m['gloss']) : null,
                    'emoji' => is_string($m['emoji'] ?? null) && trim($m['emoji']) !== '' ? trim($m['emoji']) : null,
                    'easy' => is_string($m['easy'] ?? null) ? trim($m['easy']) : null,
                    'phrase' => is_string($m['phrase'] ?? null) ? trim($m['phrase']) : null,
                    'long' => is_string($m['long'] ?? null) ? trim($m['long']) : null,
                ];
            }
        }

        return $out;
    }

    /**
     * Correcciones de una narración de un minuto: comentario, versión más natural y errores (máx. 5).
     *
     * @return array{reply: string, better: ?string, feedback: ?string, used: array, mistakes: array}
     */
    public function narration(string $topic, string $text, ?string $level = null): array
    {
        $level = $level ?: 'A2-B1';
        $types = implode(', ', array_keys(config('speaking.mistake_categories')));
        $in = $this->inLang();
        $system = <<<TXT
You are an English speaking coach for a Spanish-speaking adult (Latin American) in Miami, level about {$level} (CEFR).
The student spoke for about one minute about: "{$topic}". What you get is a speech-to-text transcript: ignore punctuation, capitalization and spelling.
Answer with exactly these lines:
- A line starting with "COMMENT:" in simple English: 1-2 friendly sentences reacting to WHAT they said (not the grammar).
- A line starting with "BETTER:" with a more natural version of what they said, same ideas, same level, max 70 words.
- A line starting with "FEEDBACK:" {$in}: one encouraging sentence about how they did.
- For each real mistake (max 5, the most useful ones), a line exactly like:
  FIX: <the student's words> => <the natural correct version> | <why, {$in}, max 12 words> | <type>
  where <type> is one of: {$types}
TXT;
        $out = self::parseTurn($this->message($system, [['role' => 'user', 'content' => $text]], 900), 5);
        $raw = $out['reply'];
        $comment = preg_match('/^COMMENT:\s*(.+)$/mi', $raw, $m) ? trim($m[1]) : trim(preg_replace('/^BETTER:.*$/mi', '', $raw));
        $better = preg_match('/^BETTER:\s*(.+)$/mi', $raw, $m) ? trim($m[1]) : null;

        return ['reply' => $comment, 'better' => $better] + $out;
    }

    /**
     * "Describe la imagen": la IA ve la misma foto y dice qué palabras te faltaron, una versión mejor y tus errores.
     *
     * @return array{reply: string, better: ?string, missed: array, feedback: ?string, used: array, mistakes: array}
     */
    public function describePicture(string $imageUrl, string $text, ?string $level = null): array
    {
        $level = $level ?: 'A2-B1';
        $types = implode(', ', array_keys(config('speaking.mistake_categories')));
        $in = $this->inLang();
        $system = <<<TXT
You are an English speaking coach for a Spanish-speaking adult (Latin American) in Miami, level about {$level} (CEFR).
The student looked at the attached photo and described it out loud. You get a speech-to-text transcript: ignore punctuation, capitalization and spelling.
Answer with exactly these lines:
- "COMMENT:" in simple English, 1-2 friendly sentences about how well they described the photo (what they saw and what they missed).
- Up to 5 lines "MISSED: <useful English word or short phrase for something clearly visible that they did not name> | <Spanish translation> | <short example sentence about the photo with the word between *asterisks*>". Prefer common, useful words for their level.
- "BETTER:" a natural description of the photo at their level using their ideas plus the missed words, max 70 words.
- "FEEDBACK:" {$in}, one encouraging sentence.
- For each real grammar or word mistake (max 4), a line exactly like:
  FIX: <the student's words> => <the natural correct version> | <why, {$in}, max 12 words> | <type>
  where <type> is one of: {$types}
TXT;
        $messages = [['role' => 'user', 'content' => [
            ['type' => 'image', 'source' => ['type' => 'url', 'url' => $imageUrl]],
            ['type' => 'text', 'text' => "My description: {$text}"],
        ]]];
        $raw = $this->message($system, $messages, 1000);
        $out = self::parseTurn($raw, 4);

        $missed = [];
        if (preg_match_all('/^MISSED:\s*(.+?)\s*\|\s*(.+?)\s*\|\s*(.+)$/mi', $raw, $all, PREG_SET_ORDER)) {
            foreach (array_slice($all, 0, 5) as $m) {
                $word = mb_strtolower(trim($m[1], " \t\"'*"));
                if ($word !== '' && preg_match("/^[a-z][a-z' -]{0,40}$/", $word)) {
                    $missed[] = ['word' => $word, 'translation' => mb_substr(trim($m[2]), 0, 120), 'example' => mb_substr(trim($m[3]), 0, 200)];
                }
            }
        }
        $rest = preg_replace('/^MISSED:.*$/mi', '', $out['reply']);
        $comment = preg_match('/^COMMENT:\s*(.+)$/mi', $rest, $m) ? trim($m[1]) : null;
        $better = preg_match('/^BETTER:\s*(.+)$/mi', $rest, $m) ? trim($m[1]) : null;

        return ['reply' => $comment ?? '', 'better' => $better, 'missed' => $missed] + $out;
    }

    /**
     * Texto original para "shadowing": frases habladas y naturales (con contracciones) para repetir como un nativo.
     *
     * @return array{title: string, sentences: string[]}
     */
    public function shadowingText(string $level, string $theme): array
    {
        $prompt = <<<TXT
Write a short, natural spoken English text for shadowing practice (the learner repeats each sentence right after hearing it).
Level: CEFR {$level}. Theme: {$theme}. It can be a short monologue or a dialogue line by line (no speaker names).
Use everyday spoken English with contractions (I'm, don't, gonna is fine) and natural rhythm.
Rules: 5 sentences, each 6 to 15 words. Use ONLY letters, spaces, apostrophes and the punctuation , . ? ! (no numbers, no quotes, no dashes).
Answer ONLY with JSON: {"title": "short English title", "sentences": ["...", "..."]}
TXT;
        $text = $this->message('You write natural spoken English for language learners.', [['role' => 'user', 'content' => $prompt]], 700);
        $start = strpos($text, '{');
        $end = strrpos($text, '}');
        $data = $start !== false && $end !== false ? json_decode(substr($text, $start, $end - $start + 1), true) : null;
        if (! is_array($data) || empty($data['sentences']) || ! is_array($data['sentences'])) {
            throw new RuntimeException('La respuesta no traía JSON válido.');
        }
        // Solo frases que la evaluación de pronunciación acepta (letras y puntuación simple).
        $sentences = array_values(array_filter(array_map(fn ($x) => is_string($x) ? trim(preg_replace('/\s+/', ' ', $x)) : '', $data['sentences']),
            fn ($x) => $x !== '' && mb_strlen($x) <= 160 && preg_match("/^[A-Za-z][A-Za-z'’,.!?\- ]*$/u", $x)));
        if (count($sentences) < 3) {
            throw new RuntimeException('El texto no traía suficientes frases válidas.');
        }

        return ['title' => mb_substr(trim((string) ($data['title'] ?? 'Shadowing')), 0, 80), 'sentences' => array_slice($sentences, 0, 6)];
    }

    /**
     * Califica una conversación de prueba (0–10) según el nivel del alumno. Devuelve [nota, explicación en español].
     *
     * @return array{0: int, 1: string}
     */
    public function gradeConversation(array $messages, string $situation, ?string $level = null): array
    {
        $level = $level ?: 'A2-B1';
        $transcript = collect($messages)->map(fn ($m) => ($m['role'] === 'user' ? 'STUDENT' : 'PARTNER').': '.$m['content'])->implode("\n");
        $in = $this->inLang();
        $system = <<<TXT
You grade a speaking test of a Spanish-speaking adult learner of English, level {$level} (CEFR).
Situation: {$situation}. The student's lines are speech-to-text transcripts: ignore punctuation, capitalization and spelling.
Grade ONLY the student's lines from 0 to 10 for THEIR level: could they handle the situation, answer what was asked,
and be understood? Grammar mistakes matter only when they block understanding. 6 = handled it well enough for their level.
Answer with exactly two lines:
SCORE: <0-10>
FEEDBACK: <{$in}, max 3 short sentences: what went well and the one thing to improve>
TXT;
        $text = $this->message($system, [['role' => 'user', 'content' => "Transcript:\n".$transcript]], 300);
        $score = preg_match('/SCORE:\s*(\d+)/i', $text, $m) ? max(0, min(10, (int) $m[1])) : 0;
        $feedback = preg_match('/FEEDBACK:\s*(.+)$/mis', $text, $m) ? trim($m[1]) : trim($text);

        return [$score, $feedback];
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
        $types = implode(', ', array_keys(config('speaking.mistake_categories')));
        $role = config("speaking.scenarios.{$scenario}.role") ?? config('speaking.scenarios.free.role');
        $level = $level ?: 'A2-B1';
        $input = $voice
            ? 'The student is SPEAKING: their messages are speech-to-text transcripts. Ignore punctuation, capitalization and spelling; correct only grammar, word choice and natural phrasing.'
            : 'The student is typing.';
        $in = $this->inLang();
        $system = <<<TXT
You are an English speaking partner for a Spanish-speaking adult (Latin American) who lives in Miami. Their level is about {$level} (CEFR).
Role-play: {$role}
Stay in character and keep the conversation going naturally. {$input}
Target words of the day (use them only when it fits naturally; praise the student when they use one): {$words}.
Rules:
- Keep each reply short (1-3 sentences, spoken style) and end with ONE question so the student keeps talking.
- Use simple, natural American English for their level. If the student seems lost, rephrase more simply.
- After your reply, add a line starting with "FEEDBACK:" written {$in}: a short, encouraging note about the student's last message (max 2 sentences).
- Then, for each real mistake in the student's last message (max 2, skip tiny ones), add a line exactly like:
  FIX: <the student's words> => <the natural correct version> | <why, {$in}, max 12 words> | <type>
  where <type> is one of: {$types}
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
    public static function parseTurn(string $text, int $maxFixes = 2): array
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
            foreach (array_slice($all, 0, $maxFixes) as $m) {
                $said = trim($m[1], " \t\"'“”");
                $correct = trim($m[2], " \t\"'“”");
                // "| por qué | tipo": el tipo va al final si es uno de los conocidos.
                $parts = isset($m[3]) ? array_map('trim', explode('|', $m[3])) : [];
                $category = count($parts) > 1 && array_key_exists(strtolower(end($parts)), config('speaking.mistake_categories', []))
                    ? strtolower(array_pop($parts)) : null;
                $why = trim(implode(' | ', $parts));
                if ($said !== '' && $correct !== '' && mb_strtolower($said) !== mb_strtolower($correct)) {
                    $mistakes[] = ['said' => mb_substr($said, 0, 300), 'correct' => mb_substr($correct, 0, 300), 'why' => $why !== '' ? mb_substr($why, 0, 300) : null, 'category' => $category];
                }
            }
        }
        $reply = trim(preg_replace(["/^(FEEDBACK|USED|FIX):.*$/mi", "/\n{3,}/"], ['', "\n\n"], $text));

        return ['reply' => $reply, 'feedback' => $feedback, 'used' => $used, 'mistakes' => $mistakes];
    }
}
