<?php

namespace App\Support;

use App\Models\Course;

/**
 * El curso «actual»: el único sitio que decide de qué curso son las palabras que se buscan.
 *
 * - En una petición de un alumno: su curso (`users.course_id`).
 * - Sin alumno (comandos, tareas, páginas públicas): el curso de siempre, inglés para hispanohablantes.
 * - Un comando o una tarea que trabaje para otro curso lo dice con `run()` y al acabar vuelve el de antes.
 *
 * `Word` lo usa en su regla global: toda búsqueda de palabras se limita sola al curso actual.
 */
class CurrentCourse
{
    private ?int $forced = null;

    public function id(): int
    {
        return $this->forced ?? (int) (auth()->user()?->course_id ?: Course::DEFAULT_ID);
    }

    /** Ejecuta $work con otro curso como actual (por ejemplo, para preparar contenido de ese curso). */
    public function run(int $courseId, callable $work): mixed
    {
        $before = $this->forced;
        $this->forced = $courseId;
        try {
            return $work();
        } finally {
            $this->forced = $before;
        }
    }
}
