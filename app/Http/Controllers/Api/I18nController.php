<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\DemoService;
use App\Services\UiTranslations;
use Illuminate\Http\Request;

/** Traducciones de la interfaz para la web y la app (como en CuPay). */
class I18nController extends Controller
{
    public function __construct(private UiTranslations $ui) {}

    /** GET /api/i18n/{lang}: todas las traducciones, con versión para no descargar dos veces. */
    public function show(Request $request, string $lang)
    {
        abort_unless($this->ui->supported($lang), 404, 'Idioma no disponible.');
        $version = $this->ui->version($lang);
        $etag = '"'.$version.'"';
        // Cloudflare lo marca como débil (W/"…"): se compara sin esa marca.
        if (str_replace('W/', '', (string) $request->header('If-None-Match')) === $etag) {
            return response('', 304)->header('ETag', $etag);
        }

        return response()->json(['lang' => $lang, 'version' => $version, 'strings' => (object) $this->ui->all($lang)])
            ->header('ETag', $etag)
            ->header('Cache-Control', 'public, max-age=300');
    }

    /** POST /api/i18n/missing: la app avisa de textos sin traducir; se traducen después con la IA. */
    public function missing(Request $request)
    {
        $max = config('i18n.max_keys_per_request');
        $data = $request->validate([
            'lang' => ['required', 'string', 'in:'.implode(',', config('i18n.languages'))],
            'keys' => ['required', 'array', 'max:'.$max],
            'keys.*' => ['string', 'max:'.config('i18n.max_key_length')],
        ]);
        // Las cuentas de la demo no anotan textos (son anónimas).
        if (DemoService::isDemo($request->user())) {
            return response()->json(['queued' => 0]);
        }

        return response()->json(['queued' => $this->ui->reportMissing($data['lang'], $data['keys'])]);
    }
}
