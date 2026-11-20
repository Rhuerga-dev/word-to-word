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

    /** @var array<int, Course> */
    private array $loaded = [];

    public function id(): int
    {
        return $this->forced ?? (int) (auth()->user()?->course_id ?: Course::DEFAULT_ID);
    }

    /** El curso actual entero (se lee una vez y se recuerda). Si no existe, el de siempre. */
    public function course(): Course
    {
        $id = $this->id();

        return $this->loaded[$id] ??= Course::find($id) ?? Course::findOrFail(Course::DEFAULT_ID);
    }

    /** Voz y reconocimiento del idioma que se aprende en el curso actual (en-US, es-US…). */
    public function speechLocale(): string
    {
        return $this->course()->speech_locale;
    }

    /**
     * Las apps nacieron con el curso de inglés y piden la voz con «en» (lo que aprendo) o «es» (mi idioma).
     * Aquí se traduce a los idiomas del curso: en el de español, «en» pasa a ser español y «es», inglés.
     * Así una app que no sabe de cursos funciona con cualquiera sin actualizarse.
     */
    public function languageFor(string $asked): string
    {
        return $asked === 'en' ? $this->course()->learn : $this->course()->from;
    }

    /** Idioma → variante para reconocer la voz del alumno cuando habla en SU idioma. */
    public function nativeLocale(): string
    {
        return ['es' => 'es-ES', 'en' => 'en-US'][$this->course()->from] ?? 'en-US';
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
