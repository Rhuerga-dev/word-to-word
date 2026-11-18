<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PetService;
use Illuminate\Http\Request;

/** La mascota Brainy del alumno: solo lectura, siempre la del usuario que ha entrado. */
class PetController extends Controller
{
    public function __invoke(Request $request, PetService $pet)
    {
        return $pet->state($request->user());
    }
}
