<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Llega por el túnel de Cloudflare a 127.0.0.1: confiar solo en ese proxy (IP real y HTTPS).
        $middleware->trustProxies(at: '127.0.0.1');
        // Cabeceras de seguridad en todas las respuestas de Laravel (sin X-Powered-By).
        $middleware->append(\App\Http\Middleware\SecurityHeaders::class);
        // Visitas reales (por Cloudflare) para la sección «Visitas» del panel de Huerga Labs.
        $middleware->append(\App\Http\Middleware\LogVisit::class);
        // Demo students: no e-mails/push and a small allowance for the paid features.
        $middleware->api(append: [\App\Http\Middleware\DemoGuard::class]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
