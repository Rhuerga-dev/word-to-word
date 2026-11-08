<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Auth\Events\Verified;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password as PasswordRule;
use Illuminate\Validation\ValidationException;
use Throwable;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            // El dominio de la demo está reservado: nadie puede registrarse con él y pasar por alumno demo.
            'email' => ['required', 'email', 'max:255', 'unique:users,email', 'not_regex:/@'.preg_quote(\App\Services\DemoService::DOMAIN, '/').'$/i'],
            'password' => ['required', 'string', PasswordRule::min(10)->letters()->numbers(), 'max:72'],
            'timezone' => ['nullable', 'timezone:all'],
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => $data['password'],
            'daily_new' => config('vocab.daily_new_default'),
            'timezone' => $data['timezone'] ?? config('vocab.timezone'),
        ]);

        $this->sendVerification($user);

        return response()->json([
            'token' => $user->createToken('app')->plainTextToken,
            'user' => $user->fresh()->profile(),
        ], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $data['email'])->first();
        // Mismo tiempo exista o no el correo: si no hay usuario se comprueba contra un hash de relleno.
        $ok = Hash::check($data['password'], $user?->password ?? self::dummyHash());
        if (! $user || ! $ok) {
            throw ValidationException::withMessages(['email' => 'Correo o contraseña incorrectos.']);
        }

        return response()->json([
            'token' => $user->createToken('app')->plainTextToken,
            'user' => $user->profile(),
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }

    public function me(Request $request)
    {
        return $request->user()->profile();
    }

    // ---------- Recuperar contraseña ----------

    /** Siempre responde lo mismo, exista o no el correo, para no revelar cuentas. */
    public function forgotPassword(Request $request)
    {
        $data = $request->validate(['email' => ['required', 'email']]);

        try {
            Password::sendResetLink(['email' => $data['email']]);
        } catch (Throwable $e) {
            report($e);
        }

        return ['message' => 'Si ese correo tiene una cuenta, te enviamos un enlace para crear una contraseña nueva.'];
    }

    public function resetPassword(Request $request)
    {
        $data = $request->validate([
            'token' => ['required', 'string'],
            'email' => ['required', 'email'],
            'password' => ['required', 'string', 'confirmed', PasswordRule::min(10)->letters()->numbers(), 'max:72'],
        ]);

        $status = Password::reset($data, function (User $user, string $password) {
            $user->forceFill(['password' => $password, 'remember_token' => Str::random(60)])->save();
            // Cierra la sesión en todos los dispositivos.
            $user->tokens()->delete();
            // Si pudo abrir el enlace del correo, el correo es suyo.
            if (! $user->hasVerifiedEmail()) {
                $user->markEmailAsVerified();
            }
            event(new PasswordReset($user));
        });

        if ($status !== Password::PASSWORD_RESET) {
            throw ValidationException::withMessages([
                'email' => 'El enlace no es válido o ya caducó. Pide uno nuevo.',
            ]);
        }

        return ['message' => 'Contraseña cambiada. Ya puedes entrar con la nueva.'];
    }

    // ---------- Verificación de correo ----------

    public function resendVerification(Request $request)
    {
        $user = $request->user();
        if ($user->hasVerifiedEmail()) {
            return ['message' => 'Tu correo ya está verificado.'];
        }
        $this->sendVerification($user);

        return ['message' => 'Te enviamos otro correo de verificación.'];
    }

    /** Enlace firmado del correo de verificación (no requiere sesión). */
    public function verify(Request $request, int $id, string $hash)
    {
        $user = User::findOrFail($id);
        abort_unless(hash_equals(sha1($user->getEmailForVerification()), $hash), 403);

        if (! $user->hasVerifiedEmail()) {
            $user->markEmailAsVerified();
            event(new Verified($user));
        }

        return redirect()->away(url('/app').'/?verified=1');
    }

    private function sendVerification(User $user): void
    {
        try {
            $user->sendEmailVerificationNotification();
        } catch (Throwable $e) {
            // Si el correo no está configurado, la cuenta se crea igual.
            report($e);
        }
    }

    /** Hash bcrypt de relleno con el mismo coste que los reales (se calcula una vez por proceso). */
    private static function dummyHash(): string
    {
        static $hash = null;

        return $hash ??= Hash::make('w2w-dummy-password');
    }
}
