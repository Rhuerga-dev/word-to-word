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
// Escalera de español: las palabras que aún nadie estudia también reciben definición en inglés (las más comunes primero).
Schedule::command('words:define --all --limit=200')->dailyAt('04:40')->withoutOverlapping();

// Borra de la base de datos los tokens de la API ya caducados.
Schedule::command('sanctum:prune-expired --hours=24')->daily();

// Borra los alumnos de la demo de más de 24 horas (también se hace al crear uno nuevo).
Schedule::call(fn () => app(\App\Services\DemoService::class)->cleanup())->hourly()->name('demo-cleanup')->withoutOverlapping();

// Textos de la interfaz que las apps no encontraron: se traducen con la IA y van a lang/en.json.
Schedule::command('i18n:translate')->everyTenMinutes()->withoutOverlapping();

// Oído: significados muy fáciles para las palabras que ya se aprendieron (cada hora, poco a poco).
Schedule::command('words:simplify --limit=100')->hourly()->withoutOverlapping();
// Y las palabras más comunes (las que salen dentro de las definiciones), poco a poco.
Schedule::command('words:simplify --all --limit=100')->hourlyAt(30)->withoutOverlapping();
