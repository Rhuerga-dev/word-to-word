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
        $code = app(CurrentCourse::class)->course()->code;

        return config("courses.{$code}.{$key}") ?? config($key, $default);
    }
}
