<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Word extends Model
{
    protected $fillable = ['course_id', 'word', 'rank', 'source', 'translation', 'example', 'example_es', 'category', 'definition', 'gloss', 'emoji', 'definition_easy', 'phrase', 'sentence_long'];

    /**
     * Regla global: una búsqueda de palabras solo ve las del curso actual (el del alumno; ver CurrentCourse),
     * y una palabra nueva nace en ese curso si no se dice otro. Así ningún sitio del código puede mezclar idiomas
     * por olvido. Para mirar todos los cursos a propósito: `Word::withoutGlobalScope('course')`.
     */
    protected static function booted(): void
    {
        static::addGlobalScope('course', function (\Illuminate\Database\Eloquent\Builder $query) {
            $query->where($query->getModel()->getTable().'.course_id', app(\App\Support\CurrentCourse::class)->id());
        });
        static::creating(function (Word $word) {
            $word->course_id ??= app(\App\Support\CurrentCourse::class)->id();
        });
    }

    public function course(): \Illuminate\Database\Eloquent\Relations\BelongsTo
    {
        return $this->belongsTo(Course::class);
    }

    /** Etiqueta y emoji de su familia, o null. */
    public function family(): ?array
    {
        $f = $this->category ? config('vocab.families.'.$this->category) : null;

        return $f ? ['key' => $this->category] + $f : null;
    }

    public function isEnriched(): bool
    {
        return filled($this->translation) && filled($this->example);
    }
}
