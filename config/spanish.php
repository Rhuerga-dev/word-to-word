<?php

/*
 * Escalera de español: la app usa cada vez menos español para que el alumno piense en inglés.
 * 1 = todo con ayuda en español · 2 = primero en inglés, español al tocar · 3 = interfaz en inglés,
 * español con límite diario · 4 = solo inglés.
 */
return [
    // Escalón de partida según el nivel del alumno.
    'base' => ['A1' => 1, 'A2' => 1, 'B1' => 2, 'B2' => 3, 'C1' => 4, 'C2' => 4],

    // Escalón máximo al empezar: la prueba de nivel mide leer; entender al OÍR suele ir por detrás.
    // Se pasa de aquí (hasta el escalón del nivel) solo cuando el alumno demuestra que entiende escuchando.
    'start_max' => 2,

    // Escucha de los últimos 7 días (ejercicio de Oído y "repeat"/"slower" en manos libres):
    // good  → al menos up_min respuestas, ≥ up_pct % de aciertos y pocas repeticiones (≤ ratio × respuestas).
    // struggling → ≥ down_min respuestas con < down_pct %, o ≥ repeats_down repeticiones: baja un escalón.
    'listening' => ['up_min' => 15, 'up_pct' => 80, 'repeats_up_ratio' => 0.1, 'down_min' => 10, 'down_pct' => 60, 'repeats_down' => 15],

    // Cuántas veces al día se puede pedir español (null = sin límite; 0 = nunca).
    'daily_limit' => [1 => null, 2 => null, 3 => 5, 4 => 0],

    // Sube un escalón solo si en los últimos 7 días estudió al menos `days` días y pidió español como mucho `max_uses` veces.
    'promote' => ['days' => 5, 'max_uses' => 3],

    // Tardar más que esto (segundos, promedio de 7 días) en empezar a hablar sugiere que está traduciendo.
    'translating_seconds' => 2.5,
];
