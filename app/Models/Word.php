<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Word extends Model
{
    protected $fillable = ['course_id', 'word', 'rank', 'source', 'translation', 'example', 'example_es', 'category', 'definition', 'gloss', 'emoji', 'definition_easy', 'phrase', 'sentence_long'];

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
