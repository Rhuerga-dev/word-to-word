<?php

namespace App\Models;

use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use NotificationChannels\WebPush\HasPushSubscriptions;

class User extends Authenticatable implements MustVerifyEmail
{
    use HasApiTokens, HasFactory, HasPushSubscriptions, Notifiable;

    protected $fillable = [
        'name', 'email', 'password', 'daily_new',
        'freelance_pack', 'family', 'reminder_enabled', 'reminder_time', 'timezone', 'speaking_goal',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'last_study_day' => 'date',
            'last_reminded_on' => 'date',
            'freelance_pack' => 'boolean',
            'reminder_enabled' => 'boolean',
        ];
    }

    public function userWords(): HasMany
    {
        return $this->hasMany(UserWord::class);
    }

    /** Lo que la app necesita saber del usuario. */
    public function profile(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'email_verified' => $this->hasVerifiedEmail(),
            'demo' => \App\Services\DemoService::isDemo($this),
            'daily_new' => $this->daily_new,
            'cefr_level' => $this->cefr_level,
            'freelance_pack' => (bool) $this->freelance_pack,
            'family' => $this->family,
            'speaking_goal' => (int) ($this->speaking_goal ?: config('speaking.default_goal', 5)),
            'reminder' => [
                'enabled' => (bool) $this->reminder_enabled,
                'time' => $this->reminder_time,
                'timezone' => $this->timezone,
            ],
        ];
    }
}
