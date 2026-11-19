<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Repetición espaciada: cada día X palabras nuevas + los repasos que tocan.
 * Dos métodos (config vocab.srs):
 * - fsrs (por defecto): cada palabra aprende cuánto la recuerdas tú (ver Fsrs).
 * - classic: saltos fijos (1, 3, 7, 15, 30, 60, 120 días); una olvidada vuelve mañana.
 * El "level" se sigue guardando en los dos, porque otras partes lo usan (dominadas, fichas sin español).
 */
class SrsService
{
    public const GRADES = ['again', 'hard', 'good', 'easy'];

    private function usesFsrs(): bool
    {
        return config('vocab.srs') === 'fsrs';
    }

    private function fsrs(): Fsrs
    {
        return new Fsrs((float) config('vocab.fsrs.retention', 0.9), (int) config('vocab.fsrs.max_days', 365));
    }

    public function today(User $user): CarbonImmutable
    {
        return CarbonImmutable::today(config('vocab.timezone'))->addDays($user->day_offset);
    }

    /** @return array{reviews: Collection, new: Collection, new_done: int, new_paused: bool} */
    public function queue(User $user): array
    {
        $today = $this->today($user);

        $reviews = UserWord::with('word')
            ->where('user_id', $user->id)
            ->whereNotNull('introduced_at')
            ->whereDate('next_review', '<=', $today)
            ->orderBy('next_review')
            ->orderBy('level')
            ->get();

        $newDone = (int) DB::table('study_days')
            ->where('user_id', $user->id)
            ->whereDate('day', $today)
            ->value('new_count');

        $remaining = max(0, $user->daily_new - $newDone);
        // Freno: con demasiados repasos atrasados no entran palabras nuevas hasta ponerse al día.
        $pauseAt = (int) config('vocab.new_pause_reviews', 0);
        $paused = $pauseAt > 0 && $reviews->count() > $pauseAt;
        if ($paused) {
            $remaining = 0;
        }

        $introducedIds = UserWord::where('user_id', $user->id)
            ->whereNotNull('introduced_at')
            ->pluck('word_id');

        $new = $this->newWords($user, $introducedIds, $remaining);

        return ['reviews' => $reviews, 'new' => $new, 'new_done' => $newDone, 'new_paused' => $paused];
    }

    /**
     * Palabras nuevas de hoy: primero el paquete de freelance (si está activo),
     * luego la lista general desde el inicio del nivel del usuario.
     */
    private function newWords(User $user, Collection $introducedIds, int $limit): Collection
    {
        if ($limit <= 0) {
            return new Collection;
        }
        $levels = app(LevelService::class);
        $pick = fn ($q, int $n) => $levels->ready($q)->whereNotIn('id', $introducedIds)->orderBy('rank')->limit($n)->get();

        // Familia elegida (cuerpo, frutas…): sus palabras van primero.
        $new = $user->family
            ? $pick(Word::where('category', $user->family), $limit)
            : new Collection;

        if ($user->freelance_pack && $new->count() < $limit) {
            $new = $new->concat($pick(Word::where('source', LevelService::FREELANCE)->whereNotIn('id', $new->pluck('id')), $limit - $new->count()));
        }

        if ($new->count() < $limit) {
            $general = $levels->general();
            if ($user->cefr_level) {
                $min = $levels->range($user->cefr_level)['min'];
                // Sin palabras importadas para su nivel: seguimos con lo que haya.
                if ($min !== null) {
                    $general->where('rank', '>=', $min);
                }
            }
            $new = $new->concat($pick($general->whereNotIn('id', $new->pluck('id')), $limit - $new->count()));
        }

        return $new->values();
    }

    public function learn(User $user, Word $word): UserWord
    {
        $today = $this->today($user);

        return DB::transaction(function () use ($user, $word, $today) {
            $uw = UserWord::firstOrNew(['user_id' => $user->id, 'word_id' => $word->id]);
            if ($uw->introduced_at) {
                return $uw; // ya aprendida; no contar dos veces
            }
            $uw->level = 0;
            $uw->introduced_at = $today;
            $uw->next_review = $today->addDays($this->interval(0));
            $uw->save();

            $this->bumpDay($user, $today, 'new_count');
            $this->markStudied($user, $today);

            return $uw;
        });
    }

    public function review(User $user, UserWord $uw, string $grade): UserWord
    {
        $today = $this->today($user);
        if ($this->usesFsrs()) {
            [$state, $days] = $this->fsrsNext($uw, $grade, $today);
            $uw->stability = $state['stability'];
            $uw->difficulty = $state['difficulty'];
            $uw->level = $grade === 'again' ? 0 : $this->levelFor($state['stability']);
            if ($grade === 'again') {
                $uw->fails++;
            }

            return $this->saveReview($user, $uw, $today, $days);
        }
        $max = count(config('vocab.intervals')) - 1;

        switch ($grade) {
            case 'again':
                $uw->level = 0;
                $uw->fails++;
                $days = $this->againDays();
                break;
            case 'hard':
                $days = max(1, (int) round($this->interval($uw->level) * 0.5));
                break;
            case 'good':
                $uw->level = min($uw->level + 1, $max);
                $days = $this->interval($uw->level);
                break;
            default: // easy
                $uw->level = min($uw->level + 2, $max);
                $days = $this->interval($uw->level);
        }

        return $this->saveReview($user, $uw, $today, $days);
    }

    private function saveReview(User $user, UserWord $uw, CarbonImmutable $today, int $days): UserWord
    {
        $uw->reviews++;
        $uw->next_review = $today->addDays($days);
        $uw->last_reviewed_on = $today;
        $uw->save();

        $this->bumpDay($user, $today, 'review_count');
        $this->markStudied($user, $today);

        return $uw;
    }

    /**
     * Estado FSRS tras calificar. Las palabras de antes de FSRS (sin stability) empiezan
     * con lo que ya sabíamos de ellas: su nivel y sus fallos.
     *
     * @return array{0: array{stability: float, difficulty: float}, 1: int}
     */
    private function fsrsNext(UserWord $uw, string $grade, CarbonImmutable $today): array
    {
        $fsrs = $this->fsrs();
        if ($uw->stability === null && $uw->reviews === 0) {
            $state = $fsrs->first($grade);
        } else {
            $s = $uw->stability ?? (float) $this->interval($uw->level);
            $d = $uw->difficulty ?? min(10.0, 5.0 + 0.5 * $uw->fails);
            $elapsed = $uw->last_reviewed_on
                ? (float) abs($this->dateOnly($uw->last_reviewed_on)->diffInDays($today))
                : $s; // sin fecha: suponemos que se repasó cuando tocaba
            $state = $fsrs->next($s, $d, $elapsed, $grade);
        }
        $days = $grade === 'again' ? $this->againDays() : $fsrs->interval($state['stability']);

        return [$state, $days];
    }

    /** Días hasta volver a ver una palabra olvidada: 0 = hoy mismo (se reaprende en la sesión), 1 = mañana. */
    private function againDays(): int
    {
        return config('vocab.relearn_same_day', true) ? 0 : 1;
    }

    /** Nivel clásico equivalente a una estabilidad (para "dominadas" y fichas sin español). */
    private function levelFor(float $stability): int
    {
        $level = 0;
        foreach (config('vocab.intervals') as $i => $days) {
            if ($stability >= $days) {
                $level = $i;
            }
        }

        return $level;
    }

    private function dateOnly(mixed $date): CarbonImmutable
    {
        $str = $date instanceof \DateTimeInterface ? $date->format('Y-m-d') : substr((string) $date, 0, 10);

        return CarbonImmutable::parse($str, config('vocab.timezone'));
    }

    /** Cuántos días pasarían con cada botón (para mostrarlo en la ficha). */
    public function previews(UserWord $uw): array
    {
        if ($this->usesFsrs()) {
            $today = $uw->user ? $this->today($uw->user) : CarbonImmutable::today(config('vocab.timezone'));
            $out = [];
            foreach (self::GRADES as $g) {
                $out[$g] = $this->fsrsNext($uw, $g, $today)[1];
            }

            return $out;
        }
        $max = count(config('vocab.intervals')) - 1;

        return [
            'again' => $this->againDays(),
            'hard' => max(1, (int) round($this->interval($uw->level) * 0.5)),
            'good' => $this->interval(min($uw->level + 1, $max)),
            'easy' => $this->interval(min($uw->level + 2, $max)),
        ];
    }

    public function stats(User $user): array
    {
        $today = $this->today($user);
        $learned = UserWord::where('user_id', $user->id)->whereNotNull('introduced_at');

        $forecast = [];
        for ($i = 1; $i <= 7; $i++) {
            $d = $today->addDays($i);
            $forecast[] = [
                'date' => $d->toDateString(),
                'count' => (clone $learned)->whereDate('next_review', $d)->count(),
            ];
        }

        return [
            'today' => $today->toDateString(),
            'learned' => (clone $learned)->count(),
            // Las que reconoces de oído sin pensar (ejercicio de Oído).
            'ear_automatic' => (clone $learned)->where('ear_level', '>=', \App\Services\EarService::AUTOMATIC_LEVEL)->count(),
            'mastered' => (clone $learned)->where('level', '>=', config('vocab.mastered_level'))->count(),
            'total_words' => Word::whereNotNull('translation')->count(),
            'streak' => $this->streak($user, $today),
            // Protectores: cada uno salva un día sin estudiar. Se gana uno cada 7 días de racha (máx. 2).
            'streak_freezes' => (int) $user->streak_freezes,
            'streak_protected' => $this->missedDays($user, $today) > 0 && $this->streak($user, $today) > 0,
            'forecast' => $forecast,
            'weak_sounds' => DB::table('phoneme_errors')
                ->where('user_id', $user->id)
                ->orderByDesc('count')
                ->limit(5)
                ->get(['phoneme', 'count', 'last_word']),
        ];
    }

    private function interval(int $level): int
    {
        $intervals = config('vocab.intervals');

        return $intervals[min($level, count($intervals) - 1)];
    }

    private function bumpDay(User $user, CarbonImmutable $day, string $column): void
    {
        DB::table('study_days')->updateOrInsert(
            ['user_id' => $user->id, 'day' => $day->toDateString()],
            ['updated_at' => now()]
        );
        DB::table('study_days')
            ->where('user_id', $user->id)
            ->whereDate('day', $day)
            ->increment($column);
    }

    /**
     * Último día de estudio en la zona horaria de la app de vocabulario.
     * (La fecha se guarda sin hora; leerla en UTC la corría 4 horas y la racha
     * de quien estudió ayer salía en 0.)
     */
    private function lastStudyDay(User $user): ?CarbonImmutable
    {
        if (! $user->last_study_day) {
            return null;
        }
        $date = $user->last_study_day instanceof \DateTimeInterface ? $user->last_study_day->format('Y-m-d') : (string) $user->last_study_day;

        return CarbonImmutable::parse(substr($date, 0, 10), config('vocab.timezone'));
    }

    /** Días sin estudiar entre el último día de estudio y hoy (0 si estudió hoy o ayer). */
    private function missedDays(User $user, CarbonImmutable $today): int
    {
        $last = $this->lastStudyDay($user);
        if (! $last) {
            return 0;
        }

        return max(0, (int) round($last->diffInDays($today, false)) - 1);
    }

    /**
     * Racha actual. Sigue viva si estudió hoy o ayer, o si los días que faltó
     * los cubren sus protectores (se gastan al volver a estudiar).
     */
    public function streak(User $user, CarbonImmutable $today): int
    {
        if (! $this->lastStudyDay($user)) {
            return 0;
        }

        return $this->missedDays($user, $today) <= (int) $user->streak_freezes ? (int) $user->streak : 0;
    }

    public function markStudied(User $user, CarbonImmutable $today): void
    {
        $last = $this->lastStudyDay($user);
        if ($last && $last->isSameDay($today)) {
            return;
        }
        $missed = $this->missedDays($user, $today);
        if ($last && $missed <= (int) $user->streak_freezes) {
            $user->streak_freezes = (int) $user->streak_freezes - $missed;
            $user->streak = (int) $user->streak + 1;
        } else {
            $user->streak = 1;
        }
        $every = (int) config('vocab.streak_freeze_every', 7);
        if ($user->streak % $every === 0 && $user->streak_freezes < (int) config('vocab.streak_freeze_max', 2)) {
            $user->streak_freezes++;
        }
        $user->last_study_day = $today;
        $user->save();
    }
}
