<?php

use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect('/app/');
});

// Enlace del correo de verificación. Va firmado, así que no necesita sesión.
Route::get('/email/verify/{id}/{hash}', [AuthController::class, 'verify'])
    ->middleware(['signed', 'throttle:6,1'])
    ->whereNumber('id')
    ->name('verification.verify');

// «Apoya mi desarrollo con un café» (Zelle y PayPal). Sin datos en el .env responde 404.
Route::get('/apoyo', \App\Http\Controllers\SupportController::class)->middleware('throttle:60,1');
