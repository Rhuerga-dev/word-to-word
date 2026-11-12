<?php

/*
 * Profesiones y objetivos del alumno: deciden qué conversaciones, unidades y temas ve.
 * Sin profesión elegida se ve todo como siempre (lo pensado para developers incluido).
 *   label: lo que ve el alumno · en: cómo se le describe a la IA · job: el puesto para entrevistas.
 */
return [
    'list' => [
        'tech' => ['label' => 'Tecnología y programación', 'emoji' => '💻', 'en' => 'a software developer', 'job' => 'web developer'],
        'health' => ['label' => 'Salud (enfermería, clínicas)', 'emoji' => '🩺', 'en' => 'a healthcare worker (nurse, medical assistant)', 'job' => 'medical assistant'],
        'construction' => ['label' => 'Construcción y oficios', 'emoji' => '🔨', 'en' => 'a construction and trades worker', 'job' => 'construction worker'],
        'restaurant' => ['label' => 'Restaurantes y cocina', 'emoji' => '🍽️', 'en' => 'a restaurant worker (cook or server)', 'job' => 'server at a restaurant'],
        'delivery' => ['label' => 'Delivery y transporte', 'emoji' => '🚚', 'en' => 'a delivery and transport driver', 'job' => 'delivery driver'],
        'sales' => ['label' => 'Ventas y atención al cliente', 'emoji' => '🛍️', 'en' => 'a retail sales and customer service worker', 'job' => 'sales associate'],
        'cleaning' => ['label' => 'Limpieza y mantenimiento', 'emoji' => '🧹', 'en' => 'a cleaning and maintenance worker', 'job' => 'maintenance worker'],
        'beauty' => ['label' => 'Belleza (peluquería, uñas)', 'emoji' => '💇', 'en' => 'a beauty professional (hair, nails)', 'job' => 'hairstylist at a salon'],
        'office' => ['label' => 'Oficina y administración', 'emoji' => '🗂️', 'en' => 'an office and administrative worker', 'job' => 'office assistant'],
        'student' => ['label' => 'Estudiante', 'emoji' => '🎓', 'en' => 'a student', 'job' => 'part-time job at a café'],
        'home' => ['label' => 'En casa, cuidando la familia', 'emoji' => '🏠', 'en' => 'a stay-at-home parent who takes care of the family', 'job' => 'part-time job at a store'],
        'other' => ['label' => 'Otro trabajo', 'emoji' => '✨', 'en' => 'a working adult', 'job' => 'job at a local business'],
    ],

    'goals' => [
        'work' => 'Para mi trabajo',
        'job' => 'Conseguir trabajo',
        'daily' => 'Vida diaria',
        'travel' => 'Viajar',
        'study' => 'Estudios',
    ],

    // Conversaciones pensadas para developers: con otra profesión se cambian por la plantilla equivalente.
    'replace' => [
        'upwork_call' => 'work_customer',
        'present_project' => 'explain_job',
        'job_interview' => 'job_interview_any',
        'standup' => 'work_boss',
    ],
];
