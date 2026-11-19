<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Una sugerencia enviada por un alumno desde la web o la app. */
class Suggestion extends Model
{
    public const TYPES = ['idea', 'bug', 'other'];

    public const PLATFORMS = ['android', 'ios', 'web'];

    public const STATUSES = ['new', 'reviewing', 'done', 'dismissed'];

    /** Tope de sugerencias por alumno y día, y entre todos (frena el abuso sin molestar a nadie normal). */
    public const DAILY_PER_USER = 10;

    public const DAILY_GLOBAL = 500;

    // user_id y status nunca se rellenan con lo que manda el cliente.
    protected $fillable = ['type', 'message', 'app_version', 'platform', 'screen'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
