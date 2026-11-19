<?php

/*
 | Experimentos A/B. Apagados, la app se comporta exactamente como siempre.
 */
return [
    // Modo Brainy: ¿practican y aprenden más quienes tienen a Brainy como pantalla principal?
    // Grupo «brainy» = Modo Brainy encendido por defecto; «control» = apagado (como hoy).
    // El alumno siempre puede cambiarlo en Ajustes y su elección se respeta.
    'brainy' => [
        'enabled' => (bool) env('BRAINY_AB_ENABLED', false),
        'start' => env('BRAINY_AB_START'),               // AAAA-MM-DD: desde ese día cuenta el experimento
        // Cuentas que no entran (la de Reynaldo). La demo tampoco entra nunca.
        'exclude_ids' => array_values(array_filter(array_map('intval', explode(',', (string) env('BRAINY_AB_EXCLUDE_IDS', '1'))))),
        // Con menos alumnos que esto en algún grupo, el informe avisa de que no se puede concluir nada.
        'min_users' => (int) env('BRAINY_AB_MIN_USERS', 20),
    ],
];
