<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserWord extends Model
{
    protected $fillable = [
        'user_id', 'word_id', 'level', 'next_review', 'introduced_at',
        'fails', 'reviews', 'aid', 'best_pron_score', 'last_pron_score', 'ear_level', 'ear_next', 'ear_ms',
    ];

    /**
     * Regla global: el progreso que se ve es el del curso actual (las palabras de otro curso que el alumno
     * estudió antes siguen guardadas, pero no cuentan ni salen mientras estudia este). Se apoya en la regla
     * de `Word`: «solo las palabras del curso actual». Para todo el progreso: `withoutGlobalScope('course')`.
     */
    protected static function booted(): void
    {
        static::addGlobalScope('course', function (\Illuminate\Database\Eloquent\Builder $query) {
            $query->whereIn($query->getModel()->getTable().'.word_id', Word::query()->select('id'));
        });
    }

    protected function casts(): array
    {
        return [
            'next_review' => 'date',
            'introduced_at' => 'date',
            'ear_next' => 'date:Y-m-d',
            'stability' => 'float',
            'difficulty' => 'float',
            'last_reviewed_on' => 'date',
        ];
    }

    public function word(): BelongsTo
    {
        return $this->belongsTo(Word::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
