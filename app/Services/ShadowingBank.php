<?php

namespace App\Services;

/**
 * Textos de shadowing escritos de antemano (database/content/shadowing.json), sin llamar a la IA:
 * {"B1": {"ordering coffee": [{"title": "...", "sentences": ["...", ...]}, ...]}, ...}
 * Si falta el nivel o el tema, devuelve null y el controlador pide uno a la IA como antes.
 */
class ShadowingBank
{
    /** Las mismas frases que acepta la evaluación de pronunciación (curso de inglés: solo letras sin acentos). */
    public const SENTENCE = "/^[A-Za-z][A-Za-z'’,.!?\- ]*$/u";

    /** En los demás cursos: letras de cualquier idioma (á, ñ…) y los signos que abren pregunta y exclamación. */
    public const SENTENCE_ANY = "/^[\p{L}¿¡][\p{L}'’,.!?¿¡\- ]*$/u";

    public static function sentencePattern(): string
    {
        return app(\App\Support\CurrentCourse::class)->course()->learn === 'en' ? self::SENTENCE : self::SENTENCE_ANY;
    }

    private static ?array $bank = null;

    private static ?string $loaded = null;

    public static function path(): string
    {
        return (string) \App\Support\CoursePack::get('speaking.shadowing_bank', database_path('content/shadowing.json'));
    }

    /** @return array{title: string, sentences: array<int, string>}|null */
    public static function pick(string $level, string $theme, int $variant): ?array
    {
        $texts = self::all()[$level][$theme] ?? [];
        $texts = array_values(array_filter(array_map([self::class, 'clean'], is_array($texts) ? $texts : [])));
        if (! $texts) {
            return null;
        }

        return $texts[max(0, $variant) % count($texts)];
    }

    private static function all(): array
    {
        $path = self::path();
        if (self::$loaded !== $path) {
            $data = is_file($path) ? json_decode((string) file_get_contents($path), true) : null;
            self::$bank = is_array($data) ? $data : [];
            self::$loaded = $path;
        }

        return self::$bank;
    }

    private static function clean($t): ?array
    {
        if (! is_array($t) || ! is_array($t['sentences'] ?? null)) {
            return null;
        }
        $sentences = array_values(array_filter(array_map(fn ($x) => is_string($x) ? trim(preg_replace('/\s+/', ' ', $x)) : '', $t['sentences']),
            fn ($x) => $x !== '' && mb_strlen($x) <= 160 && preg_match(self::sentencePattern(), $x)));

        return count($sentences) >= 3
            ? ['title' => mb_substr(trim((string) ($t['title'] ?? 'Shadowing')), 0, 80), 'sentences' => array_slice($sentences, 0, 6)]
            : null;
    }
}
