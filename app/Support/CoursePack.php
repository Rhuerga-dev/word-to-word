<?php

namespace App\Support;

/**
 * El «paquete» de contenido de un curso: conversaciones, temas, unidades, profesiones, tipos de error…
 *
 * El contenido de siempre (inglés para hispanohablantes) vive donde estaba: config/speaking.php,
 * config/units.php y config/professions.php. Un curso nuevo solo escribe LO QUE CAMBIA en
 * config/courses.php, bajo su código (por ejemplo 'es-en'); lo que no escriba, lo hereda.
 *
 * Regla: lo que es CONTENIDO se pide con CoursePack::get('speaking.scenarios'); lo que es una REGLA del
 * motor (metas, tiempos, umbrales) se sigue pidiendo con config(): es igual para todos los cursos.
 */
class CoursePack
{
    public static function get(string $key, mixed $default = null): mixed
    {
        $pack = (array) config('courses.'.app(CurrentCourse::class)->course()->code, []);
        if (\Illuminate\Support\Arr::has($pack, $key)) {
            return \Illuminate\Support\Arr::get($pack, $key);
        }
        // Si el paquete ya trae una lista entera (p. ej. «units.levels»), lo que no esté en ella NO se hereda:
        // pedir «units.levels.A1» a un curso que definió sus niveles sin A1 da vacío, no las unidades de inglés.
        $parts = explode('.', $key);
        for ($n = count($parts) - 1; $n >= 2; $n--) {
            if (\Illuminate\Support\Arr::has($pack, implode('.', array_slice($parts, 0, $n)))) {
                return $default;
            }
        }

        return config($key, $default);
    }
}
