<?php

use Illuminate\Support\Facades\Schedule;

// Recordatorio diario de estudio (notificaciones push).
// En el servidor hace falta el cron: * * * * * php /ruta/a/word-to-word/artisan schedule:run
Schedule::command('reminders:send')->everyFiveMinutes()->withoutOverlapping();

// Caché de voces: borra audios viejos y no deja que pase de 500 MB.
Schedule::command('tts:prune')->daily()->withoutOverlapping();

// Definiciones en inglés para las fichas avanzadas (sin español) de lo que los alumnos ya estudian.
// Palabras de las unidades del Camino que falten.
Schedule::command('units:sync')->dailyAt('04:00')->withoutOverlapping();

Schedule::command('words:define --limit=200')->dailyAt('04:10')->withoutOverlapping();

// Borra de la base de datos los tokens de la API ya caducados.
Schedule::command('sanctum:prune-expired --hours=24')->daily();

// Borra los alumnos de la demo de más de 24 horas (también se hace al crear uno nuevo).
Schedule::call(fn () => app(\App\Services\DemoService::class)->cleanup())->hourly()->name('demo-cleanup')->withoutOverlapping();
