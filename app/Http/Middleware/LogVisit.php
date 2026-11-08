<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

/**
 * Anota las visitas reales (las que llegan por Cloudflare) en storage/logs/visits.jsonl,
 * que el panel de Huerga Labs muestra en «Visitas».
 *
 * Sin IP: solo un identificador anónimo (hash con APP_KEY), el país/región/ciudad que añade
 * Cloudflare, la página, el navegador y el usuario si ha iniciado sesión.
 * Una línea por visitante (y usuario) cada 30 minutos. Nunca rompe la petición.
 */
class LogVisit
{
    private const MAX_BYTES = 5 * 1024 * 1024;

    /** Tráfico de máquinas, no de personas: pantallas, webhooks, salud. */
    private const SKIP = ['up', 'player/*', '*/player/*', 'stripe/*', '*webhook*', 'api/ai/*', 'build/*', 'favicon.ico', 'robots.txt'];

    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        try {
            $this->record($request, $response);
        } catch (\Throwable) {
            // Las estadísticas nunca pueden tumbar la app.
        }

        return $response;
    }

    private function record(Request $request, Response $response): void
    {
        // Solo tráfico de internet: las comprobaciones del panel (127.0.0.1) no traen esta cabecera.
        $ip = (string) $request->header('CF-Connecting-IP');
        if ($ip === '' || $request->isMethod('OPTIONS') || $request->is(...self::SKIP)) {
            return;
        }

        $user = $request->user();
        $visitor = substr(hash_hmac('sha256', $ip.'|'.$request->userAgent(), (string) config('app.key')), 0, 16);
        $seen = 'visit:'.$visitor.':'.($user?->getAuthIdentifier() ?? '-');
        if (! Cache::store('file')->add($seen, 1, now()->addMinutes(30))) {
            return;
        }

        $country = strtoupper((string) $request->header('CF-IPCountry'));
        $referer = parse_url((string) $request->headers->get('referer'), PHP_URL_HOST);

        $line = json_encode(array_filter([
            't' => now()->toIso8601String(),
            'v' => $visitor,
            'country' => preg_match('/^[A-Z]{2}$/', $country) && $country !== 'XX' ? $country : null,
            'region' => $request->header('CF-Region'),
            'city' => $request->header('CF-IPCity'),
            'path' => mb_substr('/'.ltrim($request->path(), '/'), 0, 120),
            'method' => $request->method(),
            'status' => $response->getStatusCode(),
            'ua' => mb_substr((string) $request->userAgent(), 0, 200),
            'user' => $user ? (string) ($user->email ?? $user->getAuthIdentifier()) : null,
            'ref' => $referer && $referer !== $request->getHost() ? $referer : null,
        ], fn ($v) => $v !== null && $v !== ''), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        $file = storage_path('logs/visits.jsonl');
        if (is_file($file) && filesize($file) > self::MAX_BYTES) {
            @rename($file, storage_path('logs/visits-1.jsonl'));
        }
        file_put_contents($file, $line."\n", FILE_APPEND | LOCK_EX);
    }
}
