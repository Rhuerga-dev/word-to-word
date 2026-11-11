<?php

/*
 * Escalera de español: la app usa cada vez menos español para que el alumno piense en inglés.
 * 1 = todo con ayuda en español · 2 = primero en inglés, español al tocar · 3 = interfaz en inglés,
 * español con límite diario · 4 = solo inglés.
 */
return [
    // Escalón de partida según el nivel del alumno.
    'base' => ['A1' => 1, 'A2' => 1, 'B1' => 2, 'B2' => 3, 'C1' => 4, 'C2' => 4],

    // Cuántas veces al día se puede pedir español (null = sin límite; 0 = nunca).
    'daily_limit' => [1 => null, 2 => null, 3 => 5, 4 => 0],

    // Sube un escalón solo si en los últimos 7 días estudió al menos `days` días y pidió español como mucho `max_uses` veces.
    'promote' => ['days' => 5, 'max_uses' => 3],

    // Tardar más que esto (segundos, promedio de 7 días) en empezar a hablar sugiere que está traduciendo.
    'translating_seconds' => 2.5,
];
