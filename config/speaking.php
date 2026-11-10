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

    // Tipos de error al hablar (la IA marca uno en cada corrección).
    'mistake_categories' => [
        'tense' => 'Tiempos verbales',
        'preposition' => 'Preposiciones',
        'article' => 'Artículos (a, an, the)',
        'word_order' => 'Orden de las palabras',
        'vocabulary' => 'Palabra equivocada',
        'agreement' => 'Concordancia (he goes, there are…)',
        'plural' => 'Plurales y contables',
        'pronoun' => 'Pronombres',
        'other' => 'Otros',
    ],

    // Narración diaria: un minuto hablando sin parar sobre un tema (uno distinto cada día).
    'narration_seconds' => 60,
    'narration_topics' => [
        ['Describe what you did this morning, step by step.', 'Describe lo que hiciste esta mañana, paso a paso.'],
        ['Explain what you are building right now and why.', 'Explica qué estás construyendo ahora y por qué.'],
        ['Talk about your plans for this weekend.', 'Habla de tus planes para el fin de semana.'],
        ['Describe your neighborhood to someone who has never been there.', 'Describe tu barrio a alguien que nunca ha ido.'],
        ['Tell the story of how you learned to code.', 'Cuenta cómo aprendiste a programar.'],
        ['Describe your perfect working day.', 'Describe tu día de trabajo perfecto.'],
        ['Explain a bug you fixed and how you found it.', 'Explica un error que arreglaste y cómo lo encontraste.'],
        ['Talk about a place you would love to travel to.', 'Habla de un lugar al que te encantaría viajar.'],
        ['Describe your favorite food and how to make it.', 'Describe tu comida favorita y cómo se prepara.'],
        ['Explain what a client should expect when they hire you.', 'Explica qué puede esperar un cliente cuando te contrata.'],
        ['Talk about something that was hard for you this week.', 'Habla de algo que te costó esta semana.'],
        ['Describe one of your apps as if you were selling it.', 'Describe una de tus apps como si la vendieras.'],
        ['Talk about a person who has influenced you.', 'Habla de una persona que te ha influido.'],
        ['Explain how you organize your day.', 'Explica cómo organizas tu día.'],
        ['Describe the weather today and how it changes your plans.', 'Describe el clima de hoy y cómo cambia tus planes.'],
        ['Talk about your goals for the next six months.', 'Habla de tus metas para los próximos seis meses.'],
        ['Explain what cybersecurity is to a friend.', 'Explica qué es la ciberseguridad a un amigo.'],
        ['Describe the last movie or series you watched.', 'Describe la última película o serie que viste.'],
        ['Talk about the differences between your home country and the US.', 'Habla de las diferencias entre tu país y Estados Unidos.'],
        ['Explain how to do something you are good at.', 'Explica cómo hacer algo que sabes hacer bien.'],
        ['Describe your ideal home.', 'Describe tu casa ideal.'],
        ['Talk about a mistake you learned from.', 'Habla de un error del que aprendiste.'],
        ['Explain why you want to speak English fluently.', 'Explica por qué quieres hablar inglés con fluidez.'],
        ['Describe what you see around you right now.', 'Describe lo que ves a tu alrededor ahora mismo.'],
        ['Talk about a tool or app you use every day.', 'Habla de una herramienta o app que usas todos los días.'],
        ['Tell a funny thing that happened to you.', 'Cuenta algo gracioso que te pasó.'],
        ['Explain how you would plan a small web project.', 'Explica cómo planearías un proyecto web pequeño.'],
        ['Talk about your family.', 'Habla de tu familia.'],
        ['Describe a typical day in your city.', 'Describe un día típico en tu ciudad.'],
        ['Talk about what you would do with an extra free day every week.', 'Habla de qué harías con un día libre extra cada semana.'],
    ],

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
