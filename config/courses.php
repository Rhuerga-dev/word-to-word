<?php

/*
 | Paquetes de contenido por curso (ver App\Support\CoursePack).
 |
 | La clave es el código del curso (tabla `courses`). Dentro, las mismas claves que config/speaking.php,
 | config/units.php y config/professions.php, pero solo las que ese curso cambia. Ejemplo:
 |
 |   'es-en' => [
 |       'speaking' => ['narration_topics' => [['Mi fin de semana', 'My weekend'], …]],
 |       'units' => ['levels' => ['A1' => […]]],
 |   ],
 |
 | `course` es la ficha del curso (idiomas, nombre, voz, si está activo): la usa `courses:load`.
 |
 | El curso de siempre ('en-es') no necesita nada aquí: su contenido es el de los archivos de siempre.
 */
return [
    'en-es' => [],

    // Español para angloparlantes. Con la misma forma que el de inglés (palabras por frecuencia y nivel, familias,
    // unidades, conversaciones). `course`: la ficha del curso; `php artisan courses:load es-en` la crea y carga sus
    // palabras de database/content/courses/es-en/words/*.json. Apagado (`active` false) hasta que esté completo.
    'es-en' => [
        'course' => ['learn' => 'es', 'from' => 'en', 'name' => 'Spanish for English speakers', 'speech_locale' => 'es-US', 'active' => false],
        // Aún sin unidades propias: el Camino sale vacío en vez de enseñar las unidades del curso de inglés.
        'units' => ['levels' => []],
    ],
];
