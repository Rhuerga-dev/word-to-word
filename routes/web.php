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
