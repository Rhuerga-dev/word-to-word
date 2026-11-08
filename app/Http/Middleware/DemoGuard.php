<?php

namespace App\Http\Middleware;

use App\Services\DemoService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

/**
 * Demo students can study, take exams and practise, but:
 * - no e-mails or push notifications (their address is not real), and
 * - a small daily allowance for the features that cost money (Claude and Azure).
 */
class DemoGuard
{
    /** [method, path] the demo can't use. */
    public const BLOCKED = [
        ['POST', 'api/email/verification-notification'],
        ['POST', 'api/push/subscriptions'],
        ['DELETE', 'api/push/subscriptions'],
        ['PUT', 'api/reminders'],
    ];

    /** Paid features: pattern => uses allowed per demo student. */
    public const QUOTAS = [
        'api/conversation' => 15,
        'api/words/*/aid/suggest' => 10,
        'api/words/*/pronunciation' => 40,
        'api/pronunciation/assess' => 60,
        'api/tts' => 400,
    ];

    /** Lo mismo para alumnos normales, por día (frena cuentas gratis creadas para gastar la IA). */
    public const USER_DAILY = [
        'api/conversation' => 60,
        'api/words/*/aid/suggest' => 40,
        'api/words/*/pronunciation' => 200,
        'api/pronunciation/assess' => 300,
        'api/tts' => 2000,
    ];

    /** Tope diario entre TODOS los usuarios: el gasto del día nunca pasa de aquí (W2W_PAID_GLOBAL_MULTIPLIER lo escala). */
    public const GLOBAL_DAILY = [
        'api/conversation' => 600,
        'api/words/*/aid/suggest' => 400,
        'api/words/*/pronunciation' => 3000,
        'api/pronunciation/assess' => 3000,
        'api/tts' => 20000,
    ];

    public function handle(Request $request, Closure $next): Response
    {
        $user = auth('sanctum')->user();
        if (! DemoService::isDemo($user)) {
            // Sin correo verificado: la mitad del límite diario (nada gratis sin verificar del todo).
            if ($user && ($limited = $this->dailyLimits($request, $user->id, $user->hasVerifiedEmail() ? 1.0 : 0.5))) {
                return $limited;
            }

            return $next($request);
        }

        // La demo también cuenta en el tope global del día (si no, abrir demos sin parar no tendría techo).
        if ($limited = $this->dailyLimits($request, null, 1.0)) {
            return $limited;
        }

        foreach (self::BLOCKED as [$method, $path]) {
            if ($request->isMethod($method) && $request->is($path)) {
                return response()->json(['message' => 'En la demo no se envían correos ni notificaciones. Crea tu cuenta para activarlos.', 'demo' => true], 403);
            }
        }

        {
            foreach (self::QUOTAS as $path => $max) {
                if ($request->is($path)) {
                    $key = 'demo:quota:'.$user->id.':'.$path;
                    $used = (int) Cache::get($key, 0);
                    if ($used >= $max) {
                        return response()->json(['message' => 'Llegaste al límite de la demo para esta función. Crea tu cuenta gratis para seguir.', 'demo' => true], 429);
                    }
                    Cache::put($key, $used + 1, now()->addDay());
                }
            }
        }

        return $next($request);
    }

    /** Cuenta un uso del día (por usuario y global) y devuelve 429 si ya se pasó. */
    private function dailyLimits(Request $request, ?int $userId, float $userScale): ?Response
    {
        $day = now()->toDateString();
        $scale = max(0.1, (float) env('W2W_PAID_GLOBAL_MULTIPLIER', 1));
        foreach (self::USER_DAILY as $path => $max) {
            if (! $request->is($path)) {
                continue;
            }
            $userKey = $userId !== null ? "paid:{$day}:{$userId}:{$path}" : null;
            $globalKey = "paid:{$day}:all:{$path}";
            if ($userKey && (int) Cache::get($userKey, 0) >= (int) ceil($max * $userScale)) {
                return response()->json(['message' => 'Llegaste al límite de hoy para esta función. Mañana se renueva.'], 429);
            }
            if ((int) Cache::get($globalKey, 0) >= (int) ceil(self::GLOBAL_DAILY[$path] * $scale)) {
                return response()->json(['message' => 'Esta función ya llegó a su límite de hoy. Mañana se renueva.'], 429);
            }
            if ($userKey) {
                Cache::add($userKey, 0, now()->addDay());
                Cache::increment($userKey);
            }
            Cache::add($globalKey, 0, now()->addDay());
            Cache::increment($globalKey);
        }

        return null;
    }
}
