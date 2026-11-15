<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InvitationCode extends Model
{
    protected $fillable = ['code', 'max_uses', 'used', 'expires_at', 'active', 'note'];

    protected function casts(): array
    {
        return ['expires_at' => 'datetime', 'active' => 'boolean', 'max_uses' => 'integer', 'used' => 'integer'];
    }

    /** Lo que ve el panel (sin datos de alumnos). */
    public function toPanel(): array
    {
        return [
            'code' => $this->code,
            'max_uses' => $this->max_uses,
            'used' => $this->used,
            'left' => max(0, $this->max_uses - $this->used),
            'expires_at' => $this->expires_at?->toIso8601String(),
            'active' => $this->active,
            'usable' => $this->active && $this->used < $this->max_uses && (! $this->expires_at || $this->expires_at->isFuture()),
            'note' => $this->note,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
