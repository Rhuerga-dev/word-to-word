<?php

// Traducciones de la interfaz (como en CuPay): lang/{idioma}.json con "texto en español" => "traducción".
// La web y la app las descargan de GET /api/i18n/{idioma}; los textos que faltan se traducen con la IA.
return [
    'path' => base_path('lang'),

    // Lo que traduce la IA sola (i18n:translate) va aquí, fuera de git: así no deja cambios sin guardar
    // en lang/ que pausan la publicación automática. Para fijarlas en git: php artisan i18n:promote.
    'learned_path' => storage_path('app/i18n'),

    // Idiomas a los que se traduce la interfaz (el español es el original).
    'languages' => ['en'],

    // Topes para los textos que avisan las apps.
    'max_keys_per_request' => 50,
    'max_key_length' => 300,
];
