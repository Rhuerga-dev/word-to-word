<?php

/*
 | La mascota Brainy: crece con lo que el alumno ya aprende en W2W.
 | Lo que sabe se calcula cada vez con datos que ya existen; la tabla `pets` solo guarda sus cuidados.
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

    /*
     | Cuidados (tipo mascota virtual): cuidarla = estudiar. Las barras van de 0 a `hearts` corazones.
     | Nunca muere: si la dejas, enferma y luego hiberna; al volver y cuidarla, despierta.
     */
    'care' => [
        'hearts' => 4,
        'start' => 2,                   // corazones de comida y ánimo al nacer
        'food_hours' => 6,              // horas despierta que tarda en perder un corazón de comida
        'joy_hours' => 8,               // …y uno de ánimo
        'night' => [22, 7],             // duerme de 22:00 a 07:00: de noche no baja nada
        'sick_after_awake_hours' => 15, // un día despierta con hambre a cero → enferma
        'sick_after_hours' => 24,       // un día entero con el desorden a tope → enferma
        'hibernate_hours' => 120,       // 5 días sin ningún cuidado → hiberna
        'wake' => 2,                    // corazones con los que despierta de la hibernación
        // Desorden = repasos y errores pendientes. Hasta N pendientes → 4, 3, 2, 1 corazones; más → 0.
        'mess' => [0, 5, 15, 30],
        // Forma adulta: hace falta haber practicado esto (en puntos) y que una cosa pese esta parte.
        'form_min' => 100,
        'form_share' => 0.5,
        // Qué da cada cosa que haces de verdad (las mismas fuentes que los puntos XP).
        'gives' => [
            'learn' => ['food' => 1, 'kind' => 'vocab'],            // palabra nueva = comida
            'review' => ['food' => 0.25, 'kind' => 'vocab'],        // repaso = merienda
            'review_again' => ['food' => 0.25, 'kind' => 'vocab'],
            'ear' => ['joy' => 0.25, 'kind' => 'ear'],              // jugar a Oído
            'pronunciation' => ['joy' => 0.25, 'kind' => 'talk'],
            'workshop' => ['cure' => true],                         // taller de un sonido = medicina
            'lab' => ['joy' => 1, 'kind' => 'talk', 'cure' => true],
            'speak' => ['joy' => 1, 'kind' => 'talk'],
            'mistake' => ['joy' => 0.5, 'kind' => 'talk'],
            'mistake_fail' => ['joy' => 0.25, 'kind' => 'talk'],
            'session' => ['joy' => 1],
            'unit' => ['food' => 1, 'joy' => 2],
        ],
    ],
];
