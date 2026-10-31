<?php

return [
    // Zona horaria que define cuándo empieza "un día nuevo" de estudio.
    'timezone' => env('VOCAB_TIMEZONE', 'America/New_York'),

    // Palabras nuevas por día por defecto (cada usuario puede cambiarlo).
    'daily_new_default' => (int) env('VOCAB_DAILY_NEW', 10),

    // Intervalos de repaso en días según el nivel de la palabra (0..6).
    'intervals' => [1, 3, 7, 15, 30, 60, 120],

    // Nivel a partir del cual una palabra cuenta como "dominada".
    'mastered_level' => 4,

    // Permite el botón "Adelantar un día" (solo para pruebas).
    'allow_time_travel' => (bool) env('VOCAB_ALLOW_TIME_TRAVEL', true),

    'anthropic' => [
        'key' => env('ANTHROPIC_API_KEY'),
        'model' => env('ANTHROPIC_MODEL', 'claude-haiku-5-5'),
        'version' => '2023-06-01',
    ],

    'azure_speech' => [
        'key' => env('AZURE_SPEECH_KEY'),
        'region' => env('AZURE_SPEECH_REGION') ?: 'eastus',
    ],
];
