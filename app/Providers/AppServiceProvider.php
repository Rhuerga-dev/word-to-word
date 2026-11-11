<?php

namespace App\Providers;

use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Auth\Notifications\VerifyEmail;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        // Login: 5/min por correo+IP y 20/min por IP. Registro y demo: por IP, también por día.
        RateLimiter::for('login', fn (Request $r) => [
            Limit::perMinute(5)->by(strtolower((string) $r->input('email')).'|'.$r->ip()),
            Limit::perMinute(20)->by($r->ip()),
        ]);
        RateLimiter::for('signup', fn (Request $r) => [
            Limit::perMinute(5)->by($r->ip()),
            Limit::perHour(10)->by($r->ip()),
            Limit::perDay(20)->by($r->ip()),
        ]);
        RateLimiter::for('demo', fn (Request $r) => [
            Limit::perMinute(6)->by($r->ip()),
            Limit::perDay(10)->by($r->ip()),
        ]);

        // Correos en español; los enlaces llevan a la app (/app/), no a vistas de Laravel.
        VerifyEmail::toMailUsing(fn ($notifiable, string $url) => (new MailMessage)
            ->subject('Confirma tu correo en W2W')
            ->greeting('¡Hola, '.$notifiable->name.'!')
            ->line('Confirma tu correo para poder recuperar tu cuenta si olvidas la contraseña.')
            ->action('Confirmar mi correo', $url)
            ->line('Si no creaste una cuenta en W2W, ignora este mensaje.'));

        ResetPassword::toMailUsing(function ($notifiable, string $token) {
            // url() quita la barra final; la añadimos para abrir /app/ directamente.
            $url = url('/app').'/?'.http_build_query([
                'reset' => $token,
                'email' => $notifiable->getEmailForPasswordReset(),
            ]);

            return (new MailMessage)
                ->subject('Crea una contraseña nueva para W2W')
                ->greeting('¡Hola, '.$notifiable->name.'!')
                ->line('Recibimos una solicitud para cambiar tu contraseña.')
                ->action('Crear contraseña nueva', $url)
                ->line('El enlace caduca en '.config('auth.passwords.users.expire', 60).' minutos.')
                ->line('Si no lo pediste tú, ignora este correo: tu contraseña no cambia.');
        });
    }
}
