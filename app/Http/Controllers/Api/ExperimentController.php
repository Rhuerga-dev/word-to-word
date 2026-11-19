<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BrainyExperiment;
use Illuminate\Http\Request;

/** La app informa del modo real que usa el alumno en un experimento (lista fija de experimentos en la ruta). */
class ExperimentController extends Controller
{
    public function store(Request $request, BrainyExperiment $brainy, string $experiment)
    {
        $data = $request->validate([
            'mode' => ['required', 'boolean'],       // Modo Brainy encendido / apagado ahora mismo
            'changed' => ['sometimes', 'boolean'],   // ¿lo cambió a mano alguna vez?
            'opened' => ['sometimes', 'boolean'],    // acaba de abrir la pantalla de Brainy
        ]);

        // Siempre a nombre del alumno de la sesión. Si no participa, no se guarda nada y la app no se entera.
        $counted = $brainy->record($request->user(), (bool) $data['mode'], (bool) ($data['changed'] ?? false), (bool) ($data['opened'] ?? false));

        return ['ok' => true, 'counted' => $counted];
    }
}
