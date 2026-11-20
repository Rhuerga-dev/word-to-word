<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Course;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Elegir curso: qué idioma aprende el alumno.
 *
 * Solo se ofrecen los cursos activos. Los que aún están apagados (en construcción) solo los ven las
 * cuentas de la lista fija de prueba (config vocab.course_testers). El progreso de cada curso se guarda
 * aparte: cambiar de curso no borra nada.
 */
class CourseController extends Controller
{
    public function index(Request $request)
    {
        return self::payload($request->user());
    }

    public function update(Request $request)
    {
        $user = $request->user();
        $codes = self::available($user)->pluck('code')->all();
        $data = $request->validate(['code' => ['required', 'string', Rule::in($codes)]]);

        // course_id no está en $fillable a propósito: solo se cambia aquí, con un código de la lista permitida.
        $user->forceFill(['course_id' => Course::where('code', $data['code'])->value('id')])->save();

        return self::payload($user->fresh()) + ['profile' => $user->fresh()->profile()];
    }

    /** Los cursos que este alumno puede elegir. */
    public static function available(User $user)
    {
        $tester = in_array((int) $user->id, config('vocab.course_testers', []), true);

        return Course::query()->when(! $tester, fn ($q) => $q->where('active', true))->orderBy('id')->get();
    }

    public static function payload(User $user): array
    {
        $current = (int) ($user->course_id ?: Course::DEFAULT_ID);

        return [
            'current' => self::available($user)->firstWhere('id', $current)?->code ?? Course::find($current)?->code,
            'courses' => self::available($user)->map(fn (Course $c) => [
                'code' => $c->code, 'name' => $c->name, 'learn' => $c->learn, 'from' => $c->from,
                'active' => $c->active, 'current' => $c->id === $current,
            ])->values()->all(),
        ];
    }
}
