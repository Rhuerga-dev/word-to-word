<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Un error al hablar que se repasa diciendo la frase correcta. */
class SpeakingMistake extends Model
{
    protected $fillable = ['user_id', 'speaking_session_id', 'said', 'correct', 'why', 'stage', 'reviews', 'reviewed_on', 'next_review', 'mastered_on'];

    protected function casts(): array
    {
        return ['reviewed_on' => 'date', 'next_review' => 'date', 'mastered_on' => 'date'];
    }

    public function toCard(): array
    {
        return [
            'id' => $this->id,
            'said' => $this->said,
            'correct' => $this->correct,
            'why' => $this->why,
            'stage' => $this->stage,
            'mastered' => $this->mastered_on !== null,
        ];
    }
}
