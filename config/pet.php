<?php

/*
 | La mascota Brainy: crece con lo que el alumno ya aprende en W2W.
 | No guarda nada: su estado se calcula cada vez con datos que ya existen.
 */
return [
    // Una palabra «se recuerda bien» cuando su memoria (stability de FSRS) aguanta estos días.
    'strong_days' => 21,

    // Puntos de crecimiento: cuánto suma cada cosa.
    'points' => [
        'word' => 1,        // cada palabra aprendida
        'strong' => 2,      // extra por cada palabra que se recuerda bien
        'unit' => 8,        // cada unidad del Camino completa
        'streak_day' => 1,  // cada día de racha…
        'streak_max' => 30, // …hasta este tope (la racha anima, no manda)
    ],

    // Etapas (diseño propio): puntos desde los que empieza cada una, de menor a mayor.
    'stages' => [
        'spark' => 0,
        'sprout' => 15,
        'curious' => 60,
        'chatty' => 180,
        'wise' => 450,
    ],

    // Cuánto hace falta para encender del todo cada zona de su cerebro.
    'targets' => [
        'words' => 300,     // palabras aprendidas
        'memory' => 150,    // palabras que se recuerdan bien
        'path' => 12,       // unidades del Camino
        'habit' => 30,      // días de racha
    ],
];
