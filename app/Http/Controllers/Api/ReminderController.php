<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class ReminderController extends Controller
{
    /** Clave pública para que el navegador se suscriba a las notificaciones. */
    public function key()
    {
        $key = config('webpush.vapid.public_key');
        abort_unless($key, 503, 'Las notificaciones no están configuradas en el servidor (VAPID_PUBLIC_KEY).');

        return ['public_key' => $key];
    }

    public function subscribe(Request $request)
    {
        $data = $request->validate([
            // Solo servicios de notificaciones push reales (si no, el servidor llamaría a cualquier URL).
            'endpoint' => ['required', 'url:https', 'max:1024', function (string $attr, mixed $value, \Closure $fail) {
                $host = strtolower((string) parse_url((string) $value, PHP_URL_HOST));
                $ok = in_array($host, ['fcm.googleapis.com', 'android.googleapis.com', 'updates.push.services.mozilla.com', 'web.push.apple.com'], true)
                    || str_ends_with($host, '.push.apple.com') || str_ends_with($host, '.notify.windows.com') || str_ends_with($host, '.push.services.mozilla.com');
                if (! $ok) {
                    $fail('Servicio de notificaciones no válido.');
                }
            }],
            'keys.p256dh' => ['required', 'string', 'max:255'],
            'keys.auth' => ['required', 'string', 'max:255'],
            'contentEncoding' => ['nullable', 'string', 'max:32'],
        ]);

        $request->user()->updatePushSubscription(
            $data['endpoint'],
            $data['keys']['p256dh'],
            $data['keys']['auth'],
            $data['contentEncoding'] ?? 'aes128gcm',
        );

        return response()->noContent();
    }

    public function unsubscribe(Request $request)
    {
        $data = $request->validate(['endpoint' => ['required', 'string', 'max:1024']]);
        $request->user()->deletePushSubscription($data['endpoint']);

        return response()->noContent();
    }

    public function update(Request $request)
    {
        $data = $request->validate([
            'enabled' => ['required', 'boolean'],
            'time' => ['required', 'date_format:H:i'],
            'timezone' => ['required', 'timezone:all'],
        ]);

        $user = $request->user();
        $changed = $user->reminder_time !== $data['time'] || $user->timezone !== $data['timezone'];
        $user->forceFill([
            'reminder_enabled' => $data['enabled'],
            'reminder_time' => $data['time'],
            'timezone' => $data['timezone'],
            // Si cambió la hora, que hoy pueda volver a avisar.
            'last_reminded_on' => $changed ? null : $user->last_reminded_on,
        ])->save();

        return $user->profile();
    }
}
