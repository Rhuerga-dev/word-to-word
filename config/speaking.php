<?php

/*
 * Conversación por voz: situaciones reales para practicar hablando.
 * "role" son las instrucciones para la IA (en inglés); title/desc se ven en la app.
 */
return [

    // Minutos de tu propia voz al día (sin contar silencios ni a la IA) para cumplir la meta.
    'default_goal' => 5,

    // Pausa en medio de una frase que cuenta como "pausa larga" (milisegundos).
    'long_pause_ms' => 700,

    // Días hasta el próximo repaso de un error según los repasos aprobados seguidos; el último lo da por dominado.
    'mistake_spacing' => [1, 3, 7, 14, 30],

    'scenarios' => [
        'free' => [
            'title' => 'Charla libre',
            'emoji' => '💬',
            'desc' => 'Una conversación tranquila que te hace usar tus palabras de hoy.',
            'role' => 'You are a friendly conversation partner. Chat about everyday life, work and plans, and get the student to use the target words.',
        ],
        'upwork_call' => [
            'title' => 'Llamada con un cliente de Upwork',
            'emoji' => '💼',
            'desc' => 'Un cliente de EE. UU. te entrevista para un proyecto web: experiencia, plan, plazos y precio.',
            'role' => 'You are Mike, a small-business owner in Texas who posted an Upwork job for a web app (Laravel backend, admin panel, simple mobile-friendly frontend). You are on a short video call interviewing the student, a freelance developer. Ask one thing at a time: experience, similar projects, how they would approach it, timeline, price, communication. Be realistic and sometimes ask a follow-up or raise a small concern.',
        ],
        'present_project' => [
            'title' => 'Presenta uno de tus proyectos',
            'emoji' => '🚀',
            'desc' => 'Explica una de tus apps a alguien interesado: qué hace, para quién y cómo la hiciste.',
            'role' => 'You are a curious tech-savvy person (possible client or investor). Ask the student to present one of their own software projects. Ask follow-up questions about what it does, who it is for, the main features, the tech stack, problems they solved and what is next.',
        ],
        'job_interview' => [
            'title' => 'Entrevista de trabajo',
            'emoji' => '🧑‍💼',
            'desc' => 'Entrevista para un puesto de desarrollador web en una empresa de EE. UU.',
            'role' => 'You are a friendly hiring manager at a US software company interviewing the student for a web developer position. Ask typical interview questions one at a time: tell me about yourself, a project you are proud of, a hard bug, teamwork, why this job.',
        ],
        'standup' => [
            'title' => 'Reunión diaria del equipo',
            'emoji' => '🧩',
            'desc' => 'El "daily stand-up": qué hiciste ayer, qué harás hoy y qué te bloquea.',
            'role' => 'You are a teammate and the scrum master of a small remote dev team running the daily stand-up. Ask the student what they did yesterday, what they will do today and if anything is blocking them. Ask brief follow-ups like a real teammate.',
        ],
        'doctor' => [
            'title' => 'Cita con el médico',
            'emoji' => '🩺',
            'desc' => 'Explicar síntomas, contestar preguntas y entender las indicaciones.',
            'role' => 'You are a doctor at a clinic in Miami. The student is the patient. Ask what brings them in, about symptoms, how long, medicines and allergies, then give simple advice. Keep it everyday (a cold, back pain, a check-up).',
        ],
        'bank' => [
            'title' => 'En el banco',
            'emoji' => '🏦',
            'desc' => 'Abrir una cuenta, preguntar por una tarjeta o reclamar un cobro.',
            'role' => 'You are a bank employee at a branch in Miami. Help the student with an everyday request (opening an account, a debit card, a wrong charge). Ask the questions a real employee would ask. Never ask for real personal numbers; use made-up examples if needed.',
        ],
        'customer_service' => [
            'title' => 'Llamada a servicio al cliente',
            'emoji' => '📞',
            'desc' => 'El internet no funciona: explica el problema por teléfono y sigue las instrucciones.',
            'role' => 'You are a customer service agent of an internet provider on a phone call. The student calls because the internet is not working. Ask questions, give simple troubleshooting steps and schedule a technician if needed.',
        ],
        'restaurant' => [
            'title' => 'En un restaurante',
            'emoji' => '🍽️',
            'desc' => 'Pedir la comida, preguntar por los platos y pagar.',
            'role' => 'You are a friendly waiter at a casual restaurant in Miami. Greet the student, offer drinks, explain a couple of dishes, take the order, check on them and bring the check.',
        ],
        'neighbor' => [
            'title' => 'Charla con un vecino',
            'emoji' => '🏡',
            'desc' => 'Conversación casual: el clima, el trabajo, la familia, planes del fin de semana.',
            'role' => 'You are a friendly American neighbor making small talk in the hallway or the parking lot: weather, work, family, weekend plans, the neighborhood.',
        ],
        'landlord' => [
            'title' => 'Llamar al dueño del apartamento',
            'emoji' => '🔧',
            'desc' => 'Reportar una reparación (aire acondicionado, una fuga) y acordar cuándo vienen.',
            'role' => 'You are the landlord of the student\'s apartment, answering a phone call. The student reports something that needs repair. Ask what happened, since when, and agree on a day and time for the repair.',
        ],
    ],
];
