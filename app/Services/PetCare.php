<?php

namespace App\Services;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Los cuidados de Brainy: comida, ánimo, limpieza y salud. Cuidarla = estudiar.
 *
 * - Comida y ánimo: se guarda «cuánto tenía y cuándo»; lo que tiene ahora se calcula con el reloj,
 *   así baja aunque la app esté cerrada. De noche duerme y no baja nada.
 * - Limpieza: no se guarda. El «desorden» son los repasos y errores pendientes.
 * - Salud: enferma si pasa un día con hambre a cero o con el desorden a tope. Se cura con la
 *   medicina (el taller de un sonido) o quitando la causa.
 * - Nunca muere: tras varios días sin cuidados hiberna; al volver a cuidarla, despierta.
 *
 * Los cuidados solo suben cuando el alumno hace algo de verdad (lo llama XpService), nunca porque la app lo pida.
 */
class PetCare
{
    public function __construct(private SrsService $srs) {}

    /** La fila del alumno; la crea la primera vez (nace con media barra). */
    public function row(User $user): object
    {
        $row = DB::table('pets')->where('user_id', $user->id)->first();
        if ($row) {
            return $row;
        }
        $now = now();
        $start = (float) config('pet.care.start');
        DB::table('pets')->insertOrIgnore([
            'user_id' => $user->id, 'food' => $start, 'food_at' => $now, 'joy' => $start, 'joy_at' => $now,
            // Nace sana aunque ya hubiera repasos atrasados: los relojes de enfermar empiezan hoy.
            'cured_at' => $now, 'last_care_at' => $now, 'created_at' => $now, 'updated_at' => $now,
        ]);

        return DB::table('pets')->where('user_id', $user->id)->first();
    }

    /** El alumno hizo algo de verdad ($source = fuente de XP): Brainy come, juega o se cura. */
    public function record(User $user, string $source, int $points = 0): void
    {
        $give = config("pet.care.gives.{$source}");
        if (! $give) {
            return;
        }
        $c = config('pet.care');
        $now = CarbonImmutable::now();
        $row = $this->row($user);
        [$food, $joy] = [$this->level($row->food, $row->food_at, $c['food_hours'], $now), $this->level($row->joy, $row->joy_at, $c['joy_hours'], $now)];

        $values = ['last_care_at' => $now, 'updated_at' => $now];
        $woke = $this->hibernating($row, $now);
        if ($woke) {                                // despierta y sigue donde estaba
            [$food, $joy] = [max($food, $c['wake']), max($joy, $c['wake'])];
            $values['cured_at'] = $now;
        }
        // Cada barra solo se toca si cambia: jugar no reinicia el reloj del hambre (ni al revés).
        if ($woke || ($give['food'] ?? 0) > 0) {
            $values += ['food' => min($c['hearts'], $food + ($give['food'] ?? 0)), 'food_at' => $now];
        }
        if ($woke || ($give['joy'] ?? 0) > 0) {
            $values += ['joy' => min($c['hearts'], $joy + ($give['joy'] ?? 0)), 'joy_at' => $now];
        }
        if ($give['cure'] ?? false) {
            $values['cured_at'] = $now;
        }
        $day = $this->srs->today($user)->toDateString();
        if (substr((string) $row->last_care_day, 0, 10) !== $day) {
            $values['last_care_day'] = $day;
            $values['care_days'] = (int) $row->care_days + 1;
        }
        if (isset($give['kind'])) {
            $column = $give['kind'].'_points';
            $values[$column] = (int) $row->{$column} + max(1, $points);
        }
        DB::table('pets')->where('id', $row->id)->update($values);
    }

    /**
     * Cómo está ahora. $stage = la etapa que le toca por puntos; devuelve también la etapa que se
     * enseña (`stage`), que nunca baja.
     */
    public function state(User $user, int $stage, array $stageKeys): array
    {
        $c = config('pet.care');
        $now = CarbonImmutable::now();
        $row = $this->grow($user, $this->row($user), $stage, $stageKeys, $now);
        $max = (int) $c['hearts'];

        $food = $this->level($row->food, $row->food_at, $c['food_hours'], $now);
        $joy = $this->level($row->joy, $row->joy_at, $c['joy_hours'], $now);
        $mess = $this->mess($user);
        $clean = $max;
        foreach ($c['mess'] as $i => $limit) {
            if (count($mess) > $limit) {
                $clean = $max - $i - 1;
            }
        }
        $clean = max(0, $clean);

        $hibernating = $this->hibernating($row, $now);
        $over = $hibernating ? 0.0 : $this->sickHours($user, $row, $mess, $now);
        $sick = $over > 0;
        $hearts = [
            'food' => $this->hearts($food, $max),
            'joy' => $this->hearts($joy, $max),
            'clean' => $clean,
            'health' => $sick ? max(1, $max - 1 - (int) floor($over / 24)) : $max,
        ];
        $asleep = $this->night($now->setTimezone(config('vocab.timezone')));

        return [
            'stage' => (int) $row->stage_max,
            'care' => [
                'needs' => array_map(fn ($h) => ['hearts' => $h, 'max' => $max], $hearts),
                'mood' => match (true) {
                    $hibernating => 'hibernating',
                    $asleep => 'asleep',
                    $sick => 'sick',
                    $hearts['food'] <= 1 => 'hungry',
                    $hearts['clean'] <= 1 => 'messy',
                    $hearts['joy'] <= 1 => 'bored',
                    min($hearts) >= $max - 1 => 'happy',
                    default => 'ok',
                },
                'asleep' => $asleep,
                'hibernating' => $hibernating,
                'sick' => $sick,
                'mess' => count($mess),
                'days' => (int) $row->care_days,
                'leaning' => $this->leaning($row),
                'form' => $row->form,
                'history' => json_decode($row->history ?: '[]', true) ?: [],
            ],
        ];
    }

    /** Borra los cuidados (al reiniciar el progreso): la mascota vuelve a nacer. */
    public function forget(User $user): void
    {
        DB::table('pets')->where('user_id', $user->id)->delete();
    }

    /** Sube la etapa guardada si creció (nunca baja), apunta la fecha y, en la última, fija su forma adulta. */
    private function grow(User $user, object $row, int $stage, array $keys, CarbonImmutable $now): object
    {
        $history = json_decode($row->history ?: '[]', true) ?: [];
        $values = [];
        if ($stage > (int) $row->stage_max || $history === []) {
            $reached = max($stage, (int) $row->stage_max);
            $history[] = ['stage' => $keys[$reached] ?? (string) $reached, 'at' => $this->srs->today($user)->toDateString()];
            $values = ['stage_max' => $reached, 'history' => json_encode($history)];
        }
        $reached = $values['stage_max'] ?? (int) $row->stage_max;
        if ($reached >= count($keys) - 1 && ! $row->form) {
            $values['form'] = $this->leaning($row) ?? 'balanced';
        }
        if ($values === []) {
            return $row;
        }
        DB::table('pets')->where('id', $row->id)->update($values + ['updated_at' => $now]);

        return (object) array_merge((array) $row, $values);
    }

    /** Hacia qué forma va según lo que más practica; null = todavía no se sabe. */
    private function leaning(object $row): ?string
    {
        $kinds = ['scholar' => (int) $row->vocab_points, 'listener' => (int) $row->ear_points, 'talker' => (int) $row->talk_points];
        $total = array_sum($kinds);
        if ($total < (int) config('pet.care.form_min')) {
            return null;
        }
        arsort($kinds);

        return current($kinds) / $total >= (float) config('pet.care.form_share') ? key($kinds) : 'balanced';
    }

    /** Corazones (con decimales) que le quedan: lo que tenía menos lo gastado en las horas despierta. */
    private function level(mixed $value, mixed $at, float $hoursPerHeart, CarbonImmutable $now): float
    {
        if (! $at) {
            return (float) $value;
        }

        return max(0.0, (float) $value - $this->awakeHours(CarbonImmutable::parse($at), $now) / $hoursPerHeart);
    }

    private function hearts(float $level, int $max): int
    {
        return (int) max(0, min($max, ceil($level - 0.0001)));
    }

    private function hibernating(object $row, CarbonImmutable $now): bool
    {
        $last = $row->last_care_at ?: $row->created_at;

        return $last && CarbonImmutable::parse($last)->diffInHours($now) >= (float) config('pet.care.hibernate_hours');
    }

    /** Fechas (Y-m-d, de vieja a nueva) de lo pendiente: repasos de palabras y errores para repasar. */
    private function mess(User $user): array
    {
        $today = $this->srs->today($user)->toDateString();
        $words = DB::table('user_words')->where('user_id', $user->id)->whereNotNull('introduced_at')
            ->whereDate('next_review', '<=', $today)->pluck('next_review');
        $mistakes = DB::table('speaking_mistakes')->where('user_id', $user->id)->whereNull('mastered_on')
            ->whereDate('next_review', '<=', $today)->pluck('next_review');
        $dates = $words->merge($mistakes)->map(fn ($d) => substr((string) $d, 0, 10))->all();
        sort($dates);

        return $dates;
    }

    /**
     * Horas que lleva enferma (0 = sana). Enferma cuando el hambre lleva a cero un día (despierta)
     * o el desorden lleva a tope un día entero; la medicina pone los dos relojes a cero.
     */
    private function sickHours(User $user, object $row, array $mess, CarbonImmutable $now): float
    {
        $c = config('pet.care');
        $cured = $row->cured_at ? CarbonImmutable::parse($row->cured_at) : null;

        // Hambre: horas despierta desde que la comida llegó a cero.
        $over = 0.0;
        if ($row->food_at) {
            $starving = $this->awakeHours(CarbonImmutable::parse($row->food_at), $now) - (float) $row->food * $c['food_hours'];
            if ($cured) {
                $starving = min($starving, $this->awakeHours($cured, $now));
            }
            // Se pasa a horas de reloj para medir las dos causas igual.
            $over = max($over, ($starving - $c['sick_after_awake_hours']) * 24 / max(1, $c['sick_after_awake_hours']));
        }

        // Desorden: está a tope desde que acabó el día en que el pendiente número (tope + 1) tocaba.
        $limit = (int) end($c['mess']);
        if (count($mess) > $limit) {
            $tz = config('vocab.timezone');
            $daysAgo = CarbonImmutable::parse($mess[$limit], $tz)->diffInDays($this->srs->today($user));
            $since = CarbonImmutable::today($tz)->subDays((int) $daysAgo)->addDay();
            if ($cured && $cured->greaterThan($since)) {
                $since = $cured;
            }
            $over = max($over, $since->diffInMinutes($now, false) / 60 - $c['sick_after_hours']);
        }

        return max(0.0, $over);
    }

    private function night(CarbonImmutable $local): bool
    {
        [$sleep, $wake] = config('pet.care.night');

        return $local->hour >= $sleep || $local->hour < $wake;
    }

    /** Horas despierta entre dos momentos (las de la noche no cuentan). */
    private function awakeHours(CarbonImmutable $from, CarbonImmutable $to): float
    {
        if ($to->lessThanOrEqualTo($from)) {
            return 0.0;
        }
        $tz = config('vocab.timezone');
        [$sleep, $wake] = config('pet.care.night');
        $to = $to->setTimezone($tz);
        // Más de 40 días da igual: ya está todo a cero.
        $from = $from->setTimezone($tz)->max($to->subDays(40));
        $asleep = 0.0;
        for ($day = $from->startOfDay()->subDay(); $day->lessThanOrEqualTo($to); $day = $day->addDay()) {
            $start = $day->setTime($sleep, 0)->max($from);
            $end = $day->addDay()->setTime($wake, 0)->min($to);
            if ($end->greaterThan($start)) {
                $asleep += $start->diffInMinutes($end) / 60;
            }
        }

        return max(0.0, $from->diffInMinutes($to) / 60 - $asleep);
    }
}
