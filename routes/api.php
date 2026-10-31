<?php

use App\Http\Controllers\Api\AidController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ConversationController;
use App\Http\Controllers\Api\PronunciationController;
use App\Http\Controllers\Api\StudyController;
use Illuminate\Support\Facades\Route;

// Todas estas rutas quedan bajo /api (Laravel 11+).

Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:10,1');
Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:10,1');
Route::get('/config', [StudyController::class, 'config']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/me', fn (\Illuminate\Http\Request $r) => $r->user()->only(['id', 'name', 'email', 'daily_new']));

    Route::get('/today', [StudyController::class, 'today']);
    Route::get('/stats', [StudyController::class, 'stats']);
    Route::put('/settings', [StudyController::class, 'settings']);
    Route::post('/debug/next-day', [StudyController::class, 'nextDay']);
    Route::post('/reset', [StudyController::class, 'reset']);

    Route::post('/words/{word}/learn', [StudyController::class, 'learn']);
    Route::post('/words/{word}/review', [StudyController::class, 'review']);

    Route::put('/words/{word}/aid', [AidController::class, 'update']);
    Route::post('/words/{word}/aid/suggest', [AidController::class, 'suggest'])->middleware('throttle:20,1');

    Route::post('/words/{word}/pronunciation', [PronunciationController::class, 'store'])->middleware('throttle:60,1');

    Route::post('/conversation', [ConversationController::class, 'store'])->middleware('throttle:30,1');
});
