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
 * Una palabra bien recordada se aleja (1, 3, 7, 15, 30, 60, 120 días);
 * una olvidada vuelve mañana.
 */
class SrsService
{
    public const GRADES = ['again', 'hard', 'good', 'easy'];

    public function today(User $user): CarbonImmutable
    {
        return CarbonImmutable::today(config('vocab.timezone'))->addDays($user->day_offset);
    }

    /** @return array{reviews: Collection, new: Collection, new_done: int} */
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

        $introducedIds = UserWord::where('user_id', $user->id)
            ->whereNotNull('introduced_at')
            ->pluck('word_id');

        $new = $this->newWords($user, $introducedIds, $remaining);

        return ['reviews' => $reviews, 'new' => $new, 'new_done' => $newDone];
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
        $max = count(config('vocab.intervals')) - 1;

        switch ($grade) {
            case 'again':
                $uw->level = 0;
                $uw->fails++;
                $days = 1;
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

        $uw->reviews++;
        $uw->next_review = $today->addDays($days);
        $uw->save();

        $this->bumpDay($user, $today, 'review_count');
        $this->markStudied($user, $today);

        return $uw;
    }

    /** Cuántos días pasarían con cada botón (para mostrarlo en la ficha). */
    public function previews(UserWord $uw): array
    {
        $max = count(config('vocab.intervals')) - 1;

        return [
            'again' => 1,
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

        $last = $this->lastStudyDay($user);
        $streakAlive = $last && $last->greaterThanOrEqualTo($today->subDay());

        return [
            'today' => $today->toDateString(),
            'learned' => (clone $learned)->count(),
            // Las que reconoces de oído sin pensar (ejercicio de Oído).
            'ear_automatic' => (clone $learned)->where('ear_level', '>=', \App\Services\EarService::AUTOMATIC_LEVEL)->count(),
            'mastered' => (clone $learned)->where('level', '>=', config('vocab.mastered_level'))->count(),
            'total_words' => Word::whereNotNull('translation')->count(),
            'streak' => $streakAlive ? $user->streak : 0,
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

    public function markStudied(User $user, CarbonImmutable $today): void
    {
        $last = $this->lastStudyDay($user);
        if ($last && $last->isSameDay($today)) {
            return;
        }
        $user->streak = ($last && $last->isSameDay($today->subDay())) ? $user->streak + 1 : 1;
        $user->last_study_day = $today;
        $user->save();
    }
}
