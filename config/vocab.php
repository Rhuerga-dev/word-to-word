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

    // Desde este nivel de repaso la ficha se estudia sin español: definición en inglés y frase con hueco.
    'english_only_level' => 3,

    // Familias de palabras (temas). La clave se guarda en words.category.
    'families' => [
        'body' => ['label' => 'Partes del cuerpo', 'emoji' => '🖐️'],
        'food' => ['label' => 'Comida', 'emoji' => '🍽️'],
        'fruits' => ['label' => 'Frutas', 'emoji' => '🍎'],
        'vegetables' => ['label' => 'Verduras', 'emoji' => '🥕'],
        'drinks' => ['label' => 'Bebidas', 'emoji' => '☕'],
        'animals' => ['label' => 'Animales', 'emoji' => '🐶'],
        'home' => ['label' => 'La casa', 'emoji' => '🏠'],
        'clothes' => ['label' => 'Ropa', 'emoji' => '👕'],
        'family' => ['label' => 'Familia', 'emoji' => '👨‍👩‍👧'],
        'colors' => ['label' => 'Colores', 'emoji' => '🎨'],
        'weather' => ['label' => 'El clima', 'emoji' => '☀️'],
        'transport' => ['label' => 'Transporte', 'emoji' => '🚗'],
        'places' => ['label' => 'Lugares de la ciudad', 'emoji' => '🏙️'],
        'feelings' => ['label' => 'Emociones', 'emoji' => '😊'],
    ],

    // Permite el botón "Adelantar un día" (solo para pruebas).
    // Apagado por defecto: actívalo solo en tu Mac para probar (VOCAB_ALLOW_TIME_TRAVEL=true).
    'allow_time_travel' => (bool) env('VOCAB_ALLOW_TIME_TRAVEL', false),

    /*
    | Niveles MCER. "from"/"to" son posiciones en la lista general por frecuencia
    | (sin contar el paquete de freelance). La NGSL cubre ~2.800 palabras; para
    | C1 hace falta importar una lista más larga.
    */
    'levels' => [
        'A1' => ['name' => 'Básico', 'from' => 1, 'to' => 500, 'can' => [
            'Presentarte y hablar de ti y de tu trabajo',
            'Entender preguntas simples si te hablan despacio',
            'Escribir mensajes cortos con frases conocidas',
        ]],
        'A2' => ['name' => 'Elemental', 'from' => 501, 'to' => 1000, 'can' => [
            'Pedir y dar información en situaciones del día a día',
            'Describir lo que haces y lo que necesitas',
            'Mantener una conversación corta con ayuda',
        ]],
        'B1' => ['name' => 'Intermedio', 'from' => 1001, 'to' => 2000, 'can' => [
            'Explicar un proyecto y responder preguntas de un cliente',
            'Entender llamadas claras sobre temas de trabajo',
            'Escribir propuestas y correos sin traductor',
        ]],
        'B2' => ['name' => 'Intermedio alto', 'from' => 2001, 'to' => 3500, 'can' => [
            'Negociar precio y plazos en una reunión',
            'Entender hablantes nativos a velocidad normal',
            'Defender tus ideas con argumentos',
        ]],
        'C1' => ['name' => 'Avanzado', 'from' => 3501, 'to' => 6000, 'can' => [
            'Hablar con fluidez y naturalidad de casi cualquier tema',
            'Entender reuniones largas y acentos variados',
            'Ajustar tu tono según la situación',
        ]],
    ],

    // Para presentar el examen de un nivel hay que haber aprendido este % de sus palabras.
    'level_exam_coverage' => 0.8,
    'level_exam_size' => 20,
    'level_exam_pass' => 0.8,          // % de aciertos para subir
    'placement_per_level' => 5,        // preguntas por nivel en la prueba inicial
    'placement_pass' => 0.7,           // % de aciertos para dar un nivel por dominado

    // Recordatorios: no enviar si pasaron más de estas horas desde la hora elegida.
    'reminder_window_hours' => 3,

    // Tarifas para medir el coste por alumno (USD; revísalas si cambian). ai:costs las usa.
    // Claude Haiku 5.5 por millón de tokens; Azure Speech pago por uso (STT por hora de audio,
    // evaluación de pronunciación = STT + extra, voz neural por millón de caracteres).
    'prices' => [
        'claude_input' => (float) env('PRICE_CLAUDE_INPUT', 0.10),
        'claude_cached' => (float) env('PRICE_CLAUDE_CACHED', 0.01),
        'claude_output' => (float) env('PRICE_CLAUDE_OUTPUT', 0.50),
        'azure_stt_hour' => (float) env('PRICE_AZURE_STT_HOUR', 1.00),
        'azure_assess_hour' => (float) env('PRICE_AZURE_ASSESS_HOUR', 1.30),
        'azure_tts_million_chars' => (float) env('PRICE_AZURE_TTS_M', 15.00),
    ],

    'anthropic' => [
        'key' => env('ANTHROPIC_API_KEY'),
        'model' => env('ANTHROPIC_MODEL', 'claude-haiku-5-5'),
        'version' => '2023-06-01',
    ],

    // Voces naturales de Azure (usan la misma clave de Azure Speech).
    'tts' => [
        'enabled' => env('TTS_ENABLED', true),
        'voice_en' => env('TTS_VOICE_EN', 'en-US-AvaMultilingualNeural'),
        'voice_es' => env('TTS_VOICE_ES', 'es-MX-DaliaNeural'),
        // Voz local Kokoro (tts-local/), opcional: solo si pones KOKORO_URL=http://127.0.0.1:8880 en el .env.
        // Se usa primero si está encendida; si no, Azure.
        'local_url' => env('KOKORO_URL'),
    ],

    'azure_speech' => [
        'key' => env('AZURE_SPEECH_KEY'),
        'region' => env('AZURE_SPEECH_REGION') ?: 'eastus',
    ],
];
