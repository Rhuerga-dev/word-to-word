<?php

namespace App\Http\Controllers;

/**
 * Página pública /apoyo: «Apoya mi desarrollo con un café» (Zelle y PayPal).
 * Los datos salen del .env (SUPPORT_ZELLE, SUPPORT_PAYPAL_URL). Sin ninguno, la página no existe (404).
 * Solo se enlaza desde la web: en la app de Android no aparece (política de pagos de Google Play).
 */
class SupportController extends Controller
{
    /** Dominios de PayPal que se aceptan en el enlace (lista fija). */
    private const PAYPAL_HOSTS = ['paypal.me', 'www.paypal.me', 'paypal.com', 'www.paypal.com'];

    /** @return array{zelle: ?string, paypal: ?string} */
    public static function options(): array
    {
        $zelle = trim((string) config('vocab.support.zelle'));
        $paypal = trim((string) config('vocab.support.paypal_url'));
        $parts = parse_url($paypal) ?: [];
        $paypalOk = ($parts['scheme'] ?? '') === 'https' && in_array(strtolower($parts['host'] ?? ''), self::PAYPAL_HOSTS, true)
            && ! isset($parts['user']) && ! isset($parts['port']);

        return [
            'zelle' => $zelle !== '' && mb_strlen($zelle) <= 120 ? $zelle : null,
            'paypal' => $paypalOk ? $paypal : null,
        ];
    }

    public static function enabled(): bool
    {
        return (bool) array_filter(self::options());
    }

    public function __invoke()
    {
        $options = self::options();
        abort_unless((bool) array_filter($options), 404);

        // Página sin scripts: solo su hoja de estilos y su icono.
        return response()->view('apoyo', $options)->header(
            'Content-Security-Policy',
            "default-src 'none'; style-src 'self'; img-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
        );
    }
}
