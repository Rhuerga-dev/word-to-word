<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Un curso: el idioma que se aprende (`learn`) y el que ya habla el alumno (`from`).
 * El primero, y el de siempre, es inglés para hispanohablantes.
 */
class Course extends Model
{
    /** El curso con el que nació W2W; todo lo anterior a los cursos le pertenece. */
    public const DEFAULT_ID = 1;

    protected $fillable = ['code', 'learn', 'from', 'name', 'speech_locale', 'active'];

    protected $casts = ['active' => 'boolean'];

    public function words(): HasMany
    {
        // Sin la regla del curso actual: aquí se piden las de ESTE curso, sea cual sea el del alumno.
        return $this->hasMany(Word::class)->withoutGlobalScope('course');
    }
}
