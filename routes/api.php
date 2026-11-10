<?php

use App\Http\Controllers\Api\AidController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ConversationController;
use App\Http\Controllers\Api\LevelController;
use App\Http\Controllers\Api\PronunciationController;
use App\Http\Controllers\Api\ReminderController;
use App\Http\Controllers\Api\SpeakingController;
use App\Http\Controllers\Api\StudyController;
use Illuminate\Support\Facades\Route;

// Todas estas rutas quedan bajo /api (Laravel 11+).

Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:signup');
Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:login');
Route::post('/auth/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1');
Route::post('/auth/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:10,1');
Route::get('/config', [StudyController::class, 'config']);

// "Probar la demo": alumno de ejemplo solo para este visitante (se borra en 24 h).
Route::post('/auth/demo', [\App\Http\Controllers\Api\DemoController::class, 'store'])->middleware('throttle:demo');

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/email/verification-notification', [AuthController::class, 'resendVerification'])->middleware('throttle:3,1');

    // Niveles MCER: prueba inicial, progreso y examen para subir.
    Route::get('/levels', [LevelController::class, 'index']);
    Route::get('/levels/placement', [LevelController::class, 'placement']);
    Route::post('/levels/placement', [LevelController::class, 'gradePlacement']);
    Route::put('/levels/current', [LevelController::class, 'choose']);
    Route::get('/levels/exam', [LevelController::class, 'exam']);
    Route::post('/levels/exam', [LevelController::class, 'gradeExam'])->middleware('throttle:10,1');

    // Recordatorios por notificación push.
    Route::get('/push/key', [ReminderController::class, 'key']);
    Route::post('/push/subscriptions', [ReminderController::class, 'subscribe']);
    Route::delete('/push/subscriptions', [ReminderController::class, 'unsubscribe']);
    Route::put('/reminders', [ReminderController::class, 'update']);

    Route::get('/today', [StudyController::class, 'today']);
    Route::get('/stats', [StudyController::class, 'stats']);
    Route::get('/families', [StudyController::class, 'families']);
    Route::put('/settings', [StudyController::class, 'settings']);
    Route::post('/debug/next-day', [StudyController::class, 'nextDay']);
    Route::post('/reset', [StudyController::class, 'reset']);

    Route::post('/words/{word}/learn', [StudyController::class, 'learn']);
    Route::post('/words/{word}/review', [StudyController::class, 'review']);

    Route::put('/words/{word}/aid', [AidController::class, 'update']);
    Route::post('/words/{word}/aid/suggest', [AidController::class, 'suggest'])->middleware('throttle:20,1');

    Route::post('/words/{word}/pronunciation', [PronunciationController::class, 'store'])->middleware('throttle:60,1');

    // Taller de pronunciación: tus sonidos difíciles, ejercicios evaluados y repetición espaciada.
    Route::get('/pronunciation/sounds', [\App\Http\Controllers\Api\PronunciationLabController::class, 'index']);
    Route::post('/pronunciation/assess', [\App\Http\Controllers\Api\PronunciationLabController::class, 'assess'])->middleware('throttle:60,1');
    Route::post('/pronunciation/sounds/result', [\App\Http\Controllers\Api\PronunciationLabController::class, 'result']);

    // Voz natural (Azure) para leer palabras, frases y consejos.
    Route::get('/tts', [\App\Http\Controllers\Api\TtsController::class, 'show'])->middleware('throttle:240,1');

    Route::post('/conversation', [ConversationController::class, 'store'])->middleware('throttle:30,1');
    Route::get('/progress', \App\Http\Controllers\Api\ProgressController::class);
    Route::get('/speaking/scenarios', [SpeakingController::class, 'scenarios']);
    Route::get('/speaking/stats', [SpeakingController::class, 'stats']);
    Route::put('/speaking/goal', [SpeakingController::class, 'goal']);
    Route::post('/speaking/sessions', [SpeakingController::class, 'start'])->middleware('throttle:20,1');
    Route::post('/speaking/sessions/{session}/turns', [SpeakingController::class, 'turn'])->middleware('throttle:40,1');
    Route::get('/speaking/picture', [SpeakingController::class, 'picture'])->middleware('throttle:20,1');
    Route::post('/speaking/sessions/{session}/picture', [SpeakingController::class, 'describe'])->middleware('throttle:10,1');
    Route::post('/words/personal', [StudyController::class, 'addPersonal'])->middleware('throttle:30,1');
    Route::post('/speaking/sessions/{session}/narration', [SpeakingController::class, 'narration'])->middleware('throttle:10,1');
    Route::post('/speaking/sessions/{session}/finish', [SpeakingController::class, 'finish']);
    Route::get('/speaking/mistakes', [SpeakingController::class, 'mistakes']);
    Route::post('/speaking/mistakes/{mistake}/review', [SpeakingController::class, 'review'])->middleware('throttle:60,1');
});
