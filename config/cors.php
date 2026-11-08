<?php

// Solo la propia web llama a la API desde el navegador (la app de /app/ está en el mismo dominio).
// Otras webs: CORS_ALLOWED_ORIGINS=https://a.com,https://b.com
return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],
    'allowed_methods' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    'allowed_origins' => array_values(array_filter(array_map('trim', array_merge(
        [rtrim((string) env('APP_URL'), '/')],
        explode(',', (string) env('CORS_ALLOWED_ORIGINS', ''))
    )))),
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['Content-Type', 'Accept', 'Authorization', 'X-Requested-With'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
