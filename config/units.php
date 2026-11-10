<?php

/*
 * Camino: unidades por nivel. Cada unidad junta palabras, un sonido, un shadowing y termina con una prueba
 * (una conversación real con la IA en una de las situaciones de config/speaking.php).
 *
 * words: palabras en inglés (las que no existan se crean con `php artisan units:sync`).
 * family: además, las palabras de esa familia (config/vocab.php → families).
 * source: además, las palabras de ese paquete (p. ej. "freelance").
 * shadow: tema del texto de shadowing.
 */
return [

    // Palabras a aprender en cada unidad (o todas las que tenga si son menos).
    'words_target' => 8,

    // Turnos mínimos en la prueba y nota para aprobarla (0–10, la pone la IA).
    'test_min_turns' => 5,
    'test_pass' => 6,

    'levels' => [
        'A1' => [
            ['id' => 'a1-hello', 'title' => 'Saludar y presentarte', 'icon' => 'hand', 'family' => 'family', 'words' => ['hello', 'name', 'meet', 'friend', 'neighbor'], 'sound' => 'ɪ', 'scenario' => 'neighbor', 'shadow' => 'meeting someone new'],
            ['id' => 'a1-food', 'title' => 'Comida y bebidas', 'icon' => 'cup', 'family' => 'food', 'words' => ['menu', 'order', 'waiter'], 'sound' => 'æ', 'scenario' => 'restaurant', 'shadow' => 'ordering coffee'],
            ['id' => 'a1-home', 'title' => 'Mi casa', 'icon' => 'home', 'family' => 'home', 'words' => ['kitchen', 'bathroom', 'rent', 'apartment'], 'sound' => 'h', 'scenario' => 'landlord', 'shadow' => 'talking about the weekend'],
            ['id' => 'a1-city', 'title' => 'La ciudad', 'icon' => 'map', 'family' => 'places', 'words' => ['store', 'bank', 'street'], 'sound' => 'ɹ', 'scenario' => 'neighbor', 'shadow' => 'asking for directions'],
            ['id' => 'a1-clothes', 'title' => 'Ropa y compras', 'icon' => 'bag', 'family' => 'clothes', 'words' => ['buy', 'size', 'cheap', 'expensive'], 'sound' => 'ʃ', 'scenario' => 'restaurant', 'shadow' => 'returning something at a store'],
            ['id' => 'a1-feelings', 'title' => 'El clima y cómo estás', 'icon' => 'sun', 'family' => 'feelings', 'words' => ['weather'], 'sound' => 'v', 'scenario' => 'neighbor', 'shadow' => 'talking about the weekend'],
        ],
        'A2' => [
            ['id' => 'a2-day', 'title' => 'Mi día a día', 'icon' => 'clock', 'words' => ['work', 'schedule', 'meeting', 'email', 'team'], 'sound' => 'ɪ', 'scenario' => 'free', 'shadow' => 'small talk with a coworker'],
            ['id' => 'a2-shopping', 'title' => 'De compras', 'icon' => 'bag', 'words' => ['store', 'price', 'receipt', 'refund', 'cash', 'card'], 'sound' => 'æ', 'scenario' => 'bank', 'shadow' => 'returning something at a store'],
            ['id' => 'a2-restaurant', 'title' => 'En el restaurante', 'icon' => 'cup', 'family' => 'drinks', 'words' => ['menu', 'dish', 'delicious', 'tip', 'bill'], 'sound' => 'θ', 'scenario' => 'restaurant', 'shadow' => 'ordering coffee'],
            ['id' => 'a2-health', 'title' => 'Salud', 'icon' => 'heart', 'family' => 'body', 'words' => ['doctor', 'pain', 'medicine', 'fever', 'sick'], 'sound' => 'i', 'scenario' => 'doctor', 'shadow' => 'at the doctor'],
            ['id' => 'a2-travel', 'title' => 'Viajes', 'icon' => 'plane', 'family' => 'transport', 'words' => ['airport', 'flight', 'ticket', 'passport', 'hotel', 'luggage'], 'sound' => 'z', 'scenario' => 'customer_service', 'shadow' => 'planning a trip'],
            ['id' => 'a2-home', 'title' => 'Problemas en casa', 'icon' => 'tool', 'words' => ['repair', 'broken', 'leak', 'landlord', 'rent'], 'sound' => 'ɹ', 'scenario' => 'landlord', 'shadow' => 'explaining a delay'],
        ],
        'B1' => [
            ['id' => 'b1-office', 'title' => 'En la oficina', 'icon' => 'briefcase', 'words' => ['meeting', 'team', 'manager', 'email', 'schedule', 'update'], 'sound' => 'ʌ', 'scenario' => 'standup', 'shadow' => 'a quick team meeting'],
            ['id' => 'b1-money', 'title' => 'Compras y dinero', 'icon' => 'card', 'words' => ['account', 'credit', 'loan', 'bill', 'pay', 'cash'], 'sound' => 'æ', 'scenario' => 'bank', 'shadow' => 'returning something at a store'],
            ['id' => 'b1-freelance', 'title' => 'Trabajo freelance', 'icon' => 'briefcase', 'source' => 'freelance', 'words' => ['client', 'budget', 'deadline', 'invoice', 'contract'], 'sound' => 'θ', 'scenario' => 'upwork_call', 'shadow' => 'a phone call with a client'],
            ['id' => 'b1-health', 'title' => 'Salud y el médico', 'icon' => 'heart', 'words' => ['appointment', 'insurance', 'health', 'medicine', 'pain'], 'sound' => 'i', 'scenario' => 'doctor', 'shadow' => 'at the doctor'],
            ['id' => 'b1-travel', 'title' => 'Viajes y problemas', 'icon' => 'plane', 'words' => ['flight', 'delay', 'trip', 'hotel', 'luggage', 'refund'], 'sound' => 'v', 'scenario' => 'customer_service', 'shadow' => 'planning a trip'],
            ['id' => 'b1-project', 'title' => 'Presentar mi proyecto', 'icon' => 'rocket', 'words' => ['project', 'feature', 'user', 'data', 'solution', 'explain'], 'sound' => 'ð', 'scenario' => 'present_project', 'shadow' => 'a phone call with a client'],
        ],
        'B2' => [
            ['id' => 'b2-interview', 'title' => 'Entrevistas de trabajo', 'icon' => 'user', 'words' => ['interview', 'experience', 'skill', 'strength', 'weakness', 'career'], 'sound' => 'ɜ', 'scenario' => 'job_interview', 'shadow' => 'a job interview answer'],
            ['id' => 'b2-negotiate', 'title' => 'Negociar con clientes', 'icon' => 'briefcase', 'source' => 'freelance', 'words' => ['negotiate', 'discount', 'offer', 'deal', 'price', 'contract'], 'sound' => 'oʊ', 'scenario' => 'upwork_call', 'shadow' => 'a phone call with a client'],
            ['id' => 'b2-meetings', 'title' => 'Reuniones y opiniones', 'icon' => 'chat', 'words' => ['opinion', 'agree', 'disagree', 'suggest', 'argue'], 'sound' => 'ɪ', 'scenario' => 'standup', 'shadow' => 'a quick team meeting'],
            ['id' => 'b2-tech', 'title' => 'Explicar problemas técnicos', 'icon' => 'code', 'words' => ['problem', 'error', 'bug', 'fix', 'server', 'update'], 'sound' => 'ʌ', 'scenario' => 'present_project', 'shadow' => 'explaining a delay'],
            ['id' => 'b2-service', 'title' => 'Reclamar un servicio', 'icon' => 'phone', 'words' => ['complaint', 'refund', 'account', 'issue', 'manager'], 'sound' => 'æ', 'scenario' => 'customer_service', 'shadow' => 'returning something at a store'],
            ['id' => 'b2-life', 'title' => 'Vida en Estados Unidos', 'icon' => 'home', 'words' => ['neighbor', 'community', 'rent', 'insurance', 'license'], 'sound' => 'z', 'scenario' => 'neighbor', 'shadow' => 'small talk with a coworker'],
        ],
        'C1' => [
            ['id' => 'c1-pitch', 'title' => 'Vender una idea', 'icon' => 'rocket', 'words' => ['pitch', 'investor', 'market', 'growth', 'revenue', 'strategy'], 'sound' => 'θ', 'scenario' => 'present_project', 'shadow' => 'a phone call with a client'],
            ['id' => 'c1-leadership', 'title' => 'Liderar un equipo', 'icon' => 'user', 'words' => ['responsibility', 'priority', 'deadline', 'feedback', 'goal'], 'sound' => 'ɹ', 'scenario' => 'standup', 'shadow' => 'a quick team meeting'],
            ['id' => 'c1-hard-client', 'title' => 'Clientes difíciles', 'icon' => 'phone', 'source' => 'freelance', 'words' => ['scope', 'expectation', 'compromise', 'requirement'], 'sound' => 'ʃ', 'scenario' => 'upwork_call', 'shadow' => 'explaining a delay'],
            ['id' => 'c1-interview', 'title' => 'Entrevista avanzada', 'icon' => 'user', 'words' => ['achievement', 'challenge', 'initiative', 'collaborate'], 'sound' => 'ð', 'scenario' => 'job_interview', 'shadow' => 'a job interview answer'],
            ['id' => 'c1-detail', 'title' => 'Explicar con detalle', 'icon' => 'heart', 'words' => ['symptom', 'treatment', 'prescription', 'diagnosis'], 'sound' => 'ʒ', 'scenario' => 'doctor', 'shadow' => 'at the doctor'],
            ['id' => 'c1-debate', 'title' => 'Debatir y convencer', 'icon' => 'chat', 'words' => ['argument', 'evidence', 'perspective', 'convince'], 'sound' => 'v', 'scenario' => 'free', 'shadow' => 'small talk with a coworker'],
        ],
    ],
];
