<?php

namespace App\Support;

/**
 * Qué ve cada alumno según su profesión.
 * Sin profesión (null) todo queda como siempre: las conversaciones de developer y sin plantillas.
 */
class Professions
{
    public static function keys(): array
    {
        return array_keys(config('professions.list'));
    }

    public static function get(?string $profession): ?array
    {
        return $profession ? config("professions.list.{$profession}") : null;
    }

    /** ¿Ve esta conversación el alumno? Usa "only", "except" y "template" de config('speaking.scenarios'). */
    public static function visible(array $scenario, ?string $profession): bool
    {
        if ($profession === null) {
            return empty($scenario['template']);
        }
        if (isset($scenario['only']) && ! in_array($profession, $scenario['only'], true)) {
            return false;
        }

        return ! in_array($profession, $scenario['except'] ?? [], true);
    }

    /** La conversación que le toca en lugar de $key (p. ej. "upwork_call" → "work_customer" si no es developer). */
    public static function scenarioFor(?string $profession, string $key): string
    {
        $all = config('speaking.scenarios');
        if (! isset($all[$key]) || self::visible($all[$key], $profession)) {
            return $key;
        }
        $alt = config("professions.replace.{$key}");

        return $alt && isset($all[$alt]) && self::visible($all[$alt], $profession) ? $alt : 'free';
    }

    /** El papel de la IA con el trabajo del alumno puesto ({job} en las plantillas). */
    public static function role(string $role, ?string $profession): string
    {
        $p = self::get($profession);

        return str_replace(['{job}', '{who}'], [$p['job'] ?? 'job at a local business', $p['en'] ?? 'a working adult'], $role);
    }

    /** Temas de narración que le tocan: los marcados con un tercer valor (p. ej. "tech") solo para esa profesión. */
    public static function topicIndexes(?string $profession): array
    {
        $out = [];
        foreach (config('speaking.narration_topics') as $i => $t) {
            if ($profession === null || ! isset($t[2]) || $t[2] === $profession) {
                $out[] = $i;
            }
        }

        return $out;
    }
}
