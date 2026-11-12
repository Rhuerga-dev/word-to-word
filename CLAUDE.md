<laravel-boost-guidelines>
# Laravel Application

This repository contains a Laravel application. Complete the following setup before working on the user's request.

## Prerequisites

Verify that PHP and Composer are available:

```sh
php -v
composer -V
```

If either command is unavailable, detect the user's operating system and install the prerequisites with the appropriate command:

macOS:

```sh
/bin/bash -c "$(curl -fsSL https://php.new/install/mac/8.5)"
```

Windows PowerShell:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://php.new/install/windows/8.5'))
```

Linux:

```sh
/bin/bash -c "$(curl -fsSL https://php.new/install/linux/8.5)"
```

After installation, ask the user to restart their terminal. If the agent needs the restarted shell to continue, ask the user to reopen their terminal and rerun their original prompt.

## Agent Setup

Install Laravel Boost from the application root before making application changes:

```sh
composer require laravel/boost --dev
php artisan boost:install
```

Boost replaces these bootstrap instructions with guidelines tailored to the application. After installation, read `AGENTS.md` again and continue with the user's original request using the generated guidelines.
</laravel-boost-guidelines>

# W2W (Word to Word)

**Antes de empezar, lee `PENDIENTES.md`** (estado, lo que falta y lo decidido). Al terminar, actualízalo.

App para aprender inglés hablando (estilo Duolingo, enfocada en fluidez). Servidor Laravel en esta carpeta
(`w2w.huergalabs.dev`) y app Flutter en `mobile/` (Android en Play con Shorebird; iPhone usa la web).
- Publicar: cambios en `main` de GitHub → el Mac prueba y publica solo (panel → «Publicación»). App Android: parche de Shorebird
  si solo cambia Dart; versión nueva en Play si cambia algo nativo o de assets.
- Conector de Claude "Huerga Labs" (`mcp.huergalabs.dev/mcp`): estado, logs, reiniciar procesos, pedir tests/push.
- Commits con autor «Reynaldo Huerga <rhuerga@iMac.local>». No romper lo que funciona: tests antes de terminar.


- Servidor: `php -S` con `router.php` (no el server.php de Laravel): sirve /app/ con cabeceras de seguridad y bloquea copias *.bak*. La lógica de la app está en `public/app/app.js`, nunca dentro de index.html.

## Reglas de seguridad (Huerga Labs) — obligatorias

Salen de las auditorías del panel. Cualquier cambio (persona o IA) las cumple; si una no aplica, se explica por qué.

**Producción**
- `.env` público: `APP_ENV=production`, `APP_DEBUG=false`, `SESSION_SECURE_COOKIE=true`, `SESSION_ENCRYPT=true`. Nunca mostrar `$e->getMessage()` al usuario: mensaje genérico y `report($e)`.
- Detrás del túnel de Cloudflare: `trustProxies(at: '127.0.0.1')` (nunca `'*'`). Redirigir HTTP→HTTPS en producción.
- Secretos solo en `.env` (nunca en código, logs, respuestas ni chat). `.gitignore` incluye `.env*`, `*.sqlite`, `_to_delete/`, `*.new`. Nada de copias `.env.bak` en el proyecto.

**Cabeceras y navegador**
- Middleware `SecurityHeaders` en todas las respuestas: CSP sin `'unsafe-inline'` en scripts (nonce con `Vite::useCspNonce()` y `$cspNonce` en cada `<script>`), `frame-ancestors 'none'`, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy`, `Permissions-Policy`, HSTS si es HTTPS, y quitar `X-Powered-By`. APIs JSON: `default-src 'none'`.
- Prohibido `onclick=`/`onchange=`… en el HTML: usar atributos `data-*` y JS en `public/js` o en un `<script>` con nonce. Toda la salida con `{{ }}`; `{!! !!}` solo con contenido ya escapado.

**Cuentas y acceso**
- Login: límite por correo+IP **y** por IP; mismo mensaje y mismo tiempo exista o no el correo (hash de relleno). Registro con `throttle:signup`.
- Contraseñas: `Password::min(10)->letters()->numbers()` y `max:72`.
- Paneles de administración: sin "recordarme", sesión ≤ 120 min, `password.confirm` antes de acciones peligrosas, MFA en Cloudflare Access.
- Tokens de API (Sanctum): `expiration` definida, `sanctum:prune-expired` diario, revocar al cerrar sesión.
- Cada consulta se limita a la empresa/usuario dueño (nunca confiar en un id que manda el cliente). Permisos por rol para cambiar ajustes de la empresa o de pagos.

**Dinero y APIs de pago (IA, SMS…)**
- Nada gratis antes de verificar el correo (créditos de bienvenida, pruebas). Registro abierto solo con códigos de invitación o verificación.
- Límite diario por usuario **y** tope global diario para toda la app. Claves de IA solo en el servidor; usar el gateway del panel (`HUERGA_AI_KEY`).

**Archivos y datos**
- Subidas: validar tipo real (`mimetypes`) y tamaño, nombre aleatorio, límite por usuario. Documentos sensibles (licencias, IDs) en disco privado, servidos con autorización, nunca en `public/`.
- Exportaciones CSV: escapar celdas que empiezan por `= + - @` (anteponer `'`).
- Comandos del sistema: `Process::run([...])` con array, nunca texto armado con datos del usuario; si no hay más remedio, `escapeshellarg` y lista de programas permitidos.

**Antes de publicar**
- `composer audit` sin vulnerabilidades, tests en verde (`php artisan test` o `./vendor/bin/phpunit`) y un test por cada regla tocada.
- El proyecto está en git (lo necesita "Arreglar con IA"). Auditar la app desde el panel después de publicarla.
