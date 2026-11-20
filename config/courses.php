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
 | El curso de siempre ('en-es') no necesita nada aquí: su contenido es el de los archivos de siempre.
 */
return [
    'en-es' => [],
];
