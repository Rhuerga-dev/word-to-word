<?php

/**
 * Router de "php -S" para Word to Word (sustituye al server.php de Laravel).
 * Los archivos estáticos de public/ (la app en /app/) los sirve el propio router, así también
 * llevan las cabeceras de seguridad; el resto va a Laravel (public/index.php), que pone las suyas.
 * Copias de seguridad (*.bak*, *.old, *.orig, *.swp) nunca se sirven.
 */
$public = __DIR__.'/public';
$uri = urldecode((string) parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH));

$path = realpath($public.$uri);
$root = realpath($public);
if ($path && is_dir($path) && is_file($path.'/index.html')) {
    $path .= '/index.html';
}

$isStatic = $uri !== '/' && $path && str_starts_with($path, $root.DIRECTORY_SEPARATOR) && is_file($path)
    && ! str_ends_with(strtolower($path), '.php');

if ($isStatic) {
    header_remove('X-Powered-By');
    if (preg_match('/(\.bak|\.old|\.orig|\.swp|~)$|\.bak-|\.bak\./i', basename($path))) {
        http_response_code(404);
        header('Content-Type: text/plain; charset=utf-8');
        echo 'Not Found';

        return true;
    }

    $types = [
        'html' => 'text/html; charset=utf-8', 'js' => 'text/javascript; charset=utf-8', 'css' => 'text/css; charset=utf-8',
        'json' => 'application/json', 'webmanifest' => 'application/manifest+json', 'txt' => 'text/plain; charset=utf-8',
        'png' => 'image/png', 'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'gif' => 'image/gif', 'webp' => 'image/webp',
        'svg' => 'image/svg+xml', 'ico' => 'image/x-icon', 'mp3' => 'audio/mpeg', 'wav' => 'audio/wav',
        'woff2' => 'font/woff2', 'woff' => 'font/woff',
    ];
    $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    header('Content-Type: '.($types[$ext] ?? 'application/octet-stream'));
    header('Content-Length: '.filesize($path));
    header('Last-Modified: '.gmdate('D, d M Y H:i:s', filemtime($path)).' GMT');
    if (in_array($ext, ['html', 'js', 'webmanifest'], true)) {
        header('Cache-Control: no-cache');   // la app y el service worker siempre se revisan
    }

    foreach (wtw_security_headers() as $name => $value) {
        header($name.': '.$value);
    }

    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'HEAD') {
        readfile($path);
    }

    return true;
}

require $public.'/index.php';

/** Cabeceras de la app estática (/app). La API las pone desde el middleware SecurityHeaders. */
function wtw_security_headers(): array
{
    $headers = [
        'Content-Security-Policy' => implode('; ', [
            "default-src 'self'",
            "script-src 'self'",
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
            "font-src 'self' https://fonts.gstatic.com",
            "img-src 'self' data: blob:",
            "media-src 'self' data: blob:",
            "connect-src 'self'",
            "worker-src 'self'",
            "manifest-src 'self'",
            "object-src 'none'",
            "base-uri 'self'",
            "form-action 'self'",
            "frame-ancestors 'none'",
        ]),
        'X-Frame-Options' => 'DENY',
        'X-Content-Type-Options' => 'nosniff',
        'Referrer-Policy' => 'strict-origin-when-cross-origin',
        // El micrófono se usa en el laboratorio de pronunciación.
        'Permissions-Policy' => 'microphone=(self), camera=(), geolocation=(), payment=(), usb=()',
    ];
    if (strtolower($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https') {
        $headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains';
    }

    return $headers;
}
