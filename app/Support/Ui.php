<?php

namespace App\Support;

use App\Services\UiTranslations;

/**
 * Textos de la interfaz que escribe el SERVIDOR (nombre del nivel, logros, tareas de hoy…).
 *
 * Se escriben en español, como siempre. Si el alumno estudia un curso cuyo idioma propio no es el español
 * (el de español para angloparlantes), salen en su idioma con el mismo diccionario que usan la web y la app
 * (lang/en.json). Si falta una traducción, sale en español: nunca se rompe nada.
 *
 * Los huecos van como :nombre →  Ui::t('Tienes :n fichas para repasar hoy.', ['n' => 3])
 *
 * En el curso de inglés no cambia nada (ahí el idioma de la pantalla lo traduce la propia app o la web).
 */
class Ui
{
    /** @var array<string, array<string, string>> diccionarios ya leídos en esta petición */
    private static array $loaded = [];

    public static function lang(): string
    {
        return app(CurrentCourse::class)->course()->from;
    }

    public static function t(string $es, array $args = []): string
    {
        $lang = self::lang();
        $text = $lang === 'es' ? $es : (self::dictionary($lang)[$es] ?? $es);
        foreach ($args as $key => $value) {
            $text = str_replace(':'.$key, (string) $value, $text);
        }

        return $text;
    }

    /** Varios textos de una vez (por ejemplo, la lista «lo que puedes hacer» de un nivel). */
    public static function many(?array $texts): array
    {
        return array_map(fn ($t) => is_string($t) ? self::t($t) : $t, $texts ?? []);
    }

    private static function dictionary(string $lang): array
    {
        return self::$loaded[$lang] ??= app(UiTranslations::class)->all($lang);
    }

    /** Para los tests: olvida los diccionarios leídos. */
    public static function forget(): void
    {
        self::$loaded = [];
    }
}
