<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Word extends Model
{
    protected $fillable = ['word', 'rank', 'source', 'translation', 'example', 'example_es'];

    public function isEnriched(): bool
    {
        return filled($this->translation) && filled($this->example);
    }
}
