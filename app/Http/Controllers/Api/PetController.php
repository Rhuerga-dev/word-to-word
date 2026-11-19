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
        // Para el experimento A/B se cuenta el botón pulsado. Un fallo aquí nunca rompe la mascota.
        try {
            app(\App\Services\BrainyExperiment::class)->careTap($request->user());
        } catch (\Throwable $e) {
            report($e);
        }

        return $pet->act($request->user(), $action);
    }

    /** PUT /pet/name: ponerle nombre a la mascota. Sin nombre (null) = «luego»: se queda como Brainy. */
    public function rename(Request $request, PetService $pet)
    {
        $request->merge(['name' => is_string($request->input('name')) ? preg_replace('/\s+/u', ' ', trim($request->input('name'))) : $request->input('name')]);
        $data = $request->validate(['name' => ['present', 'nullable', 'string', 'regex:'.PetService::NAME_RULE]], [
            'name.regex' => 'El nombre debe tener de 2 a 20 letras o números.',
        ]);

        return $pet->rename($request->user(), $data['name'] ?: null);
    }
}
