<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Una conversación por voz y cómo fue el ritmo al hablar. */
class SpeakingSession extends Model
{
    protected $fillable = ['user_id', 'scenario', 'day', 'turns', 'words', 'speech_ms', 'long_pauses', 'ended_at'];

    protected function casts(): array
    {
        return ['day' => 'date', 'ended_at' => 'datetime'];
    }

    public function mistakes(): HasMany
    {
        return $this->hasMany(SpeakingMistake::class);
    }

    /** Palabras por minuto mientras hablabas (null si aún no hay suficiente). */
    public function wpm(): ?int
    {
        return $this->words >= 3 && $this->speech_ms > 0 ? (int) round($this->words / ($this->speech_ms / 60000)) : null;
    }
}
