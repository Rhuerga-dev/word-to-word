<?php

namespace App\Services;

use App\Models\SpeakingMistake;
use App\Models\SpeakingSession;
use App\Models\User;
use Carbon\CarbonImmutable;

/** Práctica hablada: tiempo y ritmo al hablar, meta diaria y errores para repasar. */
class SpeakingService
{
    public function __construct(private SrsService $srs) {}

    /** Suma lo que se habló en un turno a la sesión. */
    public function addTurn(SpeakingSession $session, array $fluency, ?int $reactionMs = null): void
    {
        $extra = [
            'words' => $session->words + (int) $fluency['words'],
            'speech_ms' => $session->speech_ms + (int) $fluency['speech_ms'],
            'long_pauses' => $session->long_pauses + (int) $fluency['long_pauses'],
        ];
        if ($reactionMs !== null) {
            $extra['reaction_ms'] = $session->reaction_ms + $reactionMs;
            $extra['reaction_turns'] = $session->reaction_turns + 1;
        }
        $session->increment('turns', 1, $extra);
    }

    /** Tema de la narración de hoy (cambia cada día; "$skip" pasa a los siguientes). */
    public function topic(User $user, int $skip = 0): array
    {
        $topics = config('speaking.narration_topics');
        $i = ((int) $this->srs->today($user)->format('z') + $user->id + $skip) % count($topics);

        return ['en' => $topics[$i][0], 'es' => $topics[$i][1], 'index' => $i];
    }

    /**
     * Guarda los errores que marcó la IA (sin repetir uno que ya se está repasando).
     *
     * @param  array<int, array{said: string, correct: string, why: ?string}>  $mistakes
     */
    public function saveMistakes(User $user, array $mistakes, ?SpeakingSession $session, CarbonImmutable $today): array
    {
        $out = [];
        foreach ($mistakes as $m) {
            $same = SpeakingMistake::where('user_id', $user->id)->whereNull('mastered_on')
                ->whereRaw('lower(correct) = ?', [mb_strtolower($m['correct'])])->first();
            if ($same) {
                $out[] = $same->toCard();

                continue;
            }
            // Se repasa hoy mismo: decir la frase bien justo después de equivocarse es lo que más fija.
            $out[] = SpeakingMistake::create([
                'user_id' => $user->id,
                'speaking_session_id' => $session?->id,
                'said' => $m['said'],
                'correct' => $m['correct'],
                'why' => $m['why'],
                'category' => $m['category'] ?? null,
                'next_review' => $today->toDateString(),
            ])->toCard();
        }

        return $out;
    }

    /** Resultado de un repaso: aprobar espacia el siguiente; fallar lo trae mañana otra vez. */
    public function review(SpeakingMistake $mistake, bool $passed, CarbonImmutable $today): array
    {
        $spacing = config('speaking.mistake_spacing');
        $stage = (int) $mistake->stage;
        $alreadyToday = $mistake->reviewed_on?->toDateString() === $today->toDateString();

        if ($passed) {
            // Aprobar dos veces el mismo día no adelanta: la memoria se fija con días de por medio.
            $stage = $alreadyToday && $stage > 0 ? $stage : min($stage + 1, count($spacing));
            $days = $spacing[$stage - 1];
        } else {
            $stage = max(0, $stage - 1);
            $days = 1;
        }

        $mistake->update([
            'stage' => $stage,
            'reviews' => $mistake->reviews + 1,
            'reviewed_on' => $today->toDateString(),
            'next_review' => $today->addDays($days)->toDateString(),
            'mastered_on' => $stage >= count($spacing) ? ($mistake->mastered_on ?? $today->toDateString()) : null,
        ]);

        return $mistake->toCard() + ['days' => $days, 'next_review' => $mistake->next_review->toDateString()];
    }

    public function goal(User $user): int
    {
        return (int) ($user->speaking_goal ?: config('speaking.default_goal', 5));
    }

    /** Minutos hablados por día (clave Y-m-d) entre dos fechas. */
    public function minutesByDay(User $user, CarbonImmutable $from, CarbonImmutable $to): array
    {
        return SpeakingSession::where('user_id', $user->id)
            ->whereDate('day', '>=', $from->toDateString())->whereDate('day', '<=', $to->toDateString())
            ->get(['day', 'speech_ms'])
            ->groupBy(fn ($s) => $s->day->toDateString())
            ->map(fn ($g) => round($g->sum('speech_ms') / 60000, 1))
            ->all();
    }

    /** Todo lo que muestra el panel de fluidez. */
    public function stats(User $user): array
    {
        $today = $this->srs->today($user);
        $goal = $this->goal($user);
        $byDay = $this->minutesByDay($user, $today->subDays(59), $today);

        $week = [];
        for ($i = 6; $i >= 0; $i--) {
            $d = $today->subDays($i);
            $week[] = ['day' => $d->toDateString(), 'minutes' => (float) ($byDay[$d->toDateString()] ?? 0)];
        }

        // Racha: días seguidos cumpliendo la meta (hoy cuenta si ya se cumplió; si no, se mira desde ayer).
        $streak = 0;
        $d = ($byDay[$today->toDateString()] ?? 0) >= $goal ? $today : $today->subDay();
        while (($byDay[$d->toDateString()] ?? 0) >= $goal) {
            $streak++;
            $d = $d->subDay();
        }

        $recent = SpeakingSession::where('user_id', $user->id)->where('words', '>=', 20)
            ->latest('id')->limit(10)->get()->reverse()->values();
        $last7 = SpeakingSession::where('user_id', $user->id)->whereDate('day', '>=', $today->subDays(6)->toDateString())->get();
        $min7 = $last7->sum('speech_ms') / 60000;

        $reacted = $last7->sum('reaction_turns');
        $narrated = SpeakingSession::where('user_id', $user->id)->where('scenario', 'narrate')->where('words', '>', 0)
            ->whereDate('day', $today->toDateString())->exists();

        return [
            'goal' => $goal,
            // Segundos de media en empezar a contestar (últimos 7 días) y por sesión, para ver si baja.
            'reaction' => $reacted ? round($last7->sum('reaction_ms') / $reacted / 1000, 1) : null,
            'reaction_trend' => $recent->filter(fn (SpeakingSession $s) => $s->reaction_turns > 0)
                ->map(fn (SpeakingSession $s) => $s->reaction())->values()->all(),
            'narrated_today' => $narrated,
            'topic' => $this->topic($user),
            'today' => (float) ($byDay[$today->toDateString()] ?? 0),
            'streak' => $streak,
            'week' => $week,
            // Ritmo de las últimas sesiones (de la más vieja a la más nueva) para ver si sube.
            'wpm' => $recent->map(fn (SpeakingSession $s) => ['day' => $s->day->toDateString(), 'wpm' => $s->wpm()])->all(),
            'pauses_per_min' => $min7 >= 0.5 ? round($last7->sum('long_pauses') / $min7, 1) : null,
            'total_minutes' => round(SpeakingSession::where('user_id', $user->id)->sum('speech_ms') / 60000, 1),
            'mistakes_due' => SpeakingMistake::where('user_id', $user->id)->whereNull('mastered_on')
                ->whereDate('next_review', '<=', $today->toDateString())->count(),
            'mistakes_mastered' => SpeakingMistake::where('user_id', $user->id)->whereNotNull('mastered_on')->count(),
        ];
    }

    /** Resumen al terminar una conversación. */
    public function summary(SpeakingSession $session): array
    {
        $min = $session->speech_ms / 60000;

        return [
            'id' => $session->id,
            'scenario' => $session->scenario,
            'turns' => $session->turns,
            'words' => $session->words,
            'minutes' => round($min, 1),
            'wpm' => $session->wpm(),
            'pauses_per_min' => $min >= 0.5 ? round($session->long_pauses / $min, 1) : null,
            'reaction' => $session->reaction(),
            'topic' => $session->topic,
            'mistakes' => $session->mistakes()->get()->map->toCard()->all(),
        ];
    }
}
