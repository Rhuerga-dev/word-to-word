<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PetService;
use Illuminate\Http\Request;

/** La mascota Brainy del alumno: siempre la del usuario que ha entrado. */
class PetController extends Controller
{
    public function __invoke(Request $request, PetService $pet)
    {
        return $pet->state($request->user());
    }

    /** POST /pet/{action}: un botón de cuidado (lista fija en la ruta). Devuelve qué ejercicio toca. */
    public function act(Request $request, PetService $pet, string $action)
    {
        return $pet->act($request->user(), $action);
    }
}
