<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserWord extends Model
{
    protected $fillable = [
        'user_id', 'word_id', 'level', 'next_review', 'introduced_at',
        'fails', 'reviews', 'aid', 'best_pron_score', 'last_pron_score',
    ];

    protected function casts(): array
    {
        return [
            'next_review' => 'date',
            'introduced_at' => 'date',
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
