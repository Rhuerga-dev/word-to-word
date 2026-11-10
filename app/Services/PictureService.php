<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Fotos de Unsplash para "Describe la imagen". Siguiendo sus reglas: la foto se muestra desde su
 * servidor (images.unsplash.com), se nombra al fotógrafo con enlace y se avisa la "descarga" al usarla.
 */
class PictureService
{
    public const HOST = 'images.unsplash.com';

    public function enabled(): bool
    {
        return filled(config('services.unsplash.key'));
    }

    public function random(?string $theme = null): array
    {
        if (! $this->enabled()) {
            throw new RuntimeException('Falta UNSPLASH_ACCESS_KEY en el archivo .env');
        }
        $themes = config('speaking.picture_themes');
        $theme = $theme && in_array($theme, $themes, true) ? $theme : $themes[array_rand($themes)];

        $res = Http::withHeaders(['Authorization' => 'Client-ID '.config('services.unsplash.key'), 'Accept-Version' => 'v1'])
            ->timeout(15)
            ->get('https://api.unsplash.com/photos/random', ['query' => $theme, 'orientation' => 'landscape', 'content_filter' => 'high']);
        if ($res->failed()) {
            throw new RuntimeException('Unsplash respondió '.$res->status());
        }
        $p = $res->json();
        $ref = '?utm_source=word_to_word&utm_medium=referral';

        // Aviso de "descarga" que piden las reglas de Unsplash (no hace falta esperar la respuesta).
        if ($dl = $p['links']['download_location'] ?? null) {
            try {
                Http::withHeaders(['Authorization' => 'Client-ID '.config('services.unsplash.key')])->timeout(5)->get($dl);
            } catch (\Throwable) {
            }
        }

        return [
            'id' => $p['id'] ?? null,
            'theme' => $theme,
            'url' => $p['urls']['regular'] ?? null,
            'alt' => $p['alt_description'] ?? null,
            'author' => $p['user']['name'] ?? 'Unsplash',
            'author_url' => ($p['user']['links']['html'] ?? 'https://unsplash.com').$ref,
            'unsplash_url' => 'https://unsplash.com/'.$ref,
        ];
    }

    /** Solo se pasan a la IA fotos de Unsplash (nunca una dirección cualquiera que mande la app). */
    public static function allowed(?string $url): bool
    {
        $parts = parse_url((string) $url);

        return ($parts['scheme'] ?? '') === 'https' && ($parts['host'] ?? '') === self::HOST;
    }
}
