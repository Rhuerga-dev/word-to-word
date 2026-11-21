<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Notifications\BrainyAlert;
use App\Services\PetService;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Avisos de Brainy en la web (push), para quien los activó en Ajustes → Brainy.
 * La app del teléfono los programa ella sola; la web no puede, así que avisa el servidor cada 5 minutos.
 * Las mismas reglas que la app, para que acompañe y no agobie:
 *  - solo si tiene hambre (comida ≤ 1 corazón) o quiere jugar (ánimo ≤ 1); nunca dormida, hibernando ni malita;
 *  - nunca de noche (de 21:00 a 8:30, hora del alumno);
 *  - como mucho 2 al día y separados 3 horas;
 *  - uno por ausencia: si no volvió a cuidarla desde el último aviso, no insiste.
 */
class SendBrainyAlerts extends Command
{
    protected $signature = 'pet:alerts';

    protected $description = 'Envía los avisos de Brainy (hambre, ganas de jugar) por notificación push';

    public const MAX_PER_DAY = 2;

    public const GAP_HOURS = 3;

    public function handle(PetService $pets): int
    {
        // Hasta que se aplique la migración (columna web_alerts), no hay nada que hacer.
        if (! \Illuminate\Support\Facades\Schema::hasColumn('pets', 'web_alerts')) {
            return self::SUCCESS;
        }
        $sent = 0;
        $ids = DB::table('pets')->where('web_alerts', true)->pluck('user_id');
        User::query()->whereIn('id', $ids)->whereHas('pushSubscriptions')->chunkById(100, function ($users) use ($pets, &$sent) {
            foreach ($users as $user) {
                try {
                    $kind = $this->due($user, $pets->state($user));
                    if ($kind === null) {
                        continue;
                    }
                    $this->mark($user);   // antes de enviar: si falla, no se reintenta cada 5 minutos
                    $state = $pets->state($user);
                    $user->notify(new BrainyAlert($kind, $state['name'] ?? PetService::DEFAULT_NAME));
                    $sent++;
                } catch (Throwable $e) {
                    report($e);
                }
            }
        });
        $this->info("Avisos de Brainy enviados: {$sent}");

        return self::SUCCESS;
    }

    /** Qué aviso toca ahora ('hungry' · 'bored') o null. */
    public function due(User $user, array $state): ?string
    {
        $care = $state['care'] ?? null;
        $row = DB::table('pets')->where('user_id', $user->id)->first();
        if (! $care || ! $row || ! $row->web_alerts || $care['asleep'] || $care['hibernating'] || $care['sick']) {
            return null;
        }
        $now = $this->localNow($user);
        $minutes = $now->hour * 60 + $now->minute;
        if ($minutes < 8 * 60 + 30 || $now->hour >= 21) {
            return null;
        }
        if ($row->web_alerted_at) {
            $last = CarbonImmutable::parse($row->web_alerted_at, 'UTC');
            if ($last->greaterThan($now->utc()->subHours(self::GAP_HOURS))) {
                return null;
            }
            if ($last->setTimezone($now->timezone)->toDateString() === $now->toDateString() && (int) $row->web_alerts_today >= self::MAX_PER_DAY) {
                return null;
            }
            // Uno por ausencia: no volvió a cuidarla desde el último aviso.
            if (! $row->last_care_at || CarbonImmutable::parse($row->last_care_at, 'UTC')->lessThanOrEqualTo($last)) {
                return null;
            }
        }
        $needs = $care['needs'] ?? [];
        if (($needs['food']['hearts'] ?? 99) <= 1) {
            return 'hungry';
        }
        if (($needs['joy']['hearts'] ?? 99) <= 1) {
            return 'bored';
        }

        return null;
    }

    private function mark(User $user): void
    {
        $row = DB::table('pets')->where('user_id', $user->id)->first();
        $now = $this->localNow($user);
        $sameDay = $row->web_alerted_at && CarbonImmutable::parse($row->web_alerted_at, 'UTC')->setTimezone($now->timezone)->toDateString() === $now->toDateString();
        DB::table('pets')->where('id', $row->id)->update([
            'web_alerted_at' => now('UTC'),
            'web_alerts_today' => $sameDay ? (int) $row->web_alerts_today + 1 : 1,
        ]);
    }

    private function localNow(User $user): CarbonImmutable
    {
        return CarbonImmutable::now($user->timezone ?: config('vocab.timezone'));
    }
}
