<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\DemoService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Borrar la cuenta y todo lo que tiene (progreso, palabras, errores, sesiones, avisos).
 * Desde la app (con sesión) o desde la página pública /cuenta/borrar/ (con correo y contraseña),
 * como pide Google Play.
 */
class AccountController extends Controller
{
    /** DELETE /api/account — desde la app: se pide la contraseña otra vez (la demo no tiene). */
    public function destroy(Request $request)
    {
        $user = $request->user();
        if (! DemoService::isDemo($user)) {
            $data = $request->validate(['password' => ['required', 'string']]);
            if (! Hash::check($data['password'], $user->password)) {
                throw ValidationException::withMessages(['password' => 'La contraseña no es correcta.']);
            }
        }
        self::erase($user);

        return response()->noContent();
    }

    /** POST /api/account/delete — desde la web, sin la app: correo y contraseña. */
    public function destroyWithPassword(Request $request)
    {
        $data = $request->validate(['email' => ['required', 'email'], 'password' => ['required', 'string']]);
        $user = User::where('email', $data['email'])->first();
        $ok = Hash::check($data['password'], $user?->password ?? '$2y$12$'.str_repeat('.', 53));
        if (! $user || ! $ok) {
            throw ValidationException::withMessages(['email' => 'Correo o contraseña incorrectos.']);
        }
        self::erase($user);

        return response()->json(['deleted' => true]);
    }

    /** Borra al usuario: sus tablas se van con él (claves foráneas en cascada) y sus sesiones abiertas. */
    public static function erase(User $user): void
    {
        DB::transaction(function () use ($user) {
            DB::table('personal_access_tokens')->where('tokenable_type', User::class)->where('tokenable_id', $user->id)->delete();
            DB::table('sessions')->where('user_id', $user->id)->delete();
            DB::table('password_reset_tokens')->where('email', $user->email)->delete();
            $user->delete();
        });
    }
}
