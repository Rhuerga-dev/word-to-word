<?php

namespace App\Http\Controllers;

/**
 * Página pública /prueba-micro: prueba la calidad de un micrófono (por ejemplo, el del carro por Bluetooth).
 * Graba unos segundos y los analiza EN EL NAVEGADOR: no se envía ni se guarda nada en el servidor.
 * Por eso no necesita cuenta ni gasta nada. No se enlaza desde la app; se abre con su dirección.
 */
class MicTestController extends Controller
{
    public function __invoke()
    {
        // Solo sus propios archivos; sin conexiones (connect-src) para que nada pueda salir del navegador.
        // media-src blob: es para volver a escuchar la grabación, que vive solo en la memoria de la página.
        return response()->view('mic-test')->header(
            'Content-Security-Policy',
            "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; media-src blob:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
        );
    }
}
