<?php

namespace App\Services;

use App\Models\SpeakingMistake;
use App\Models\SpeakingSession;
use App\Models\User;
use App\Models\UserWord;
use Illuminate\Support\Facades\DB;

/** Panel de progreso: vocabulario, hablar, pronunciación, errores y lo que conviene hacer hoy. */
class ProgressService
{
    public function __construct(
        private SrsService $srs,
        private SpeakingService $speaking,
        private LevelService $levels,
    ) {}

    public function overview(User $user): array
    {
        $today = $this->srs->today($user);
        $srsStats = $this->srs->stats($user);
        $speak = $this->speaking->stats($user);

        // Vocabulario: cuántas palabras hay en cada nivel de repaso (0 = recién aprendida).
        $byLevel = UserWord::where('user_id', $user->id)->whereNotNull('introduced_at')
            ->selectRaw('level, count(*) as n')->groupBy('level')->pluck('n', 'level');
        $levels = count(config('vocab.intervals'));
        $dueWords = UserWord::where('user_id', $user->id)->whereNotNull('introduced_at')
            ->whereDate('next_review', '<=', $today->toDateString())->count();

        // Hablar: minutos por semana (8 semanas, de la más vieja a la actual).
        $from = $today->startOfWeek()->subWeeks(7);
        $byDay = $this->speaking->minutesByDay($user, $from, $today);
        $weeks = [];
        for ($w = 0; $w < 8; $w++) {
            $start = $from->addWeeks($w);
            $min = 0;
            for ($d = 0; $d < 7; $d++) {
                $min += $byDay[$start->addDays($d)->toDateString()] ?? 0;
            }
            $weeks[] = ['week' => $start->toDateString(), 'minutes' => round($min, 1)];
        }

        // Pronunciación: cada sonido con su nivel.
        $sounds = DB::table('phoneme_errors')->where('user_id', $user->id)->orderByDesc('count')->get()
            ->map(fn ($s) => [
                'phoneme' => $s->phoneme,
                'tier' => $s->tier ?? 'g',
                'stage' => (int) $s->stage,
                'mastered' => (bool) $s->mastered_on,
                'errors' => (int) $s->count,
                'due' => ! $s->mastered_on && (! $s->next_practice || substr($s->next_practice, 0, 10) <= $today->toDateString()),
            ])->values();

        // Errores: los tipos que más se repiten entre los que aún no se superan.
        $labels = config('speaking.mistake_categories');
        $pending = SpeakingMistake::where('user_id', $user->id)->whereNull('mastered_on');
        $byCategory = (clone $pending)->selectRaw("coalesce(category, 'other') as cat, count(*) as n")->groupBy('cat')
            ->orderByDesc('n')->get()
            ->map(fn ($r) => ['category' => $r->cat, 'label' => $labels[$r->cat] ?? $labels['other'], 'count' => (int) $r->n])->values();

        $level = $this->levels->progress($user);
        $data = [
            'today' => $today->toDateString(),
            'vocab' => [
                'learned' => $srsStats['learned'],
                'mastered' => $srsStats['mastered'],
                'total' => $srsStats['total_words'],
                'streak' => $srsStats['streak'],
                'due' => $dueWords,
                'by_level' => array_map(fn ($l) => (int) ($byLevel[$l] ?? 0), range(0, $levels)),
            ],
            'level' => $level,
            'speaking' => [
                'weeks' => $weeks,
                'today' => $speak['today'],
                'goal' => $speak['goal'],
                'streak' => $speak['streak'],
                'wpm' => array_values(array_filter(array_column($speak['wpm'], 'wpm'))),
                'reaction' => $speak['reaction_trend'],
                'pauses_per_min' => $speak['pauses_per_min'],
                'total_minutes' => $speak['total_minutes'],
                'narrated_today' => $speak['narrated_today'],
            ],
            'pronunciation' => ['sounds' => $sounds],
            'mistakes' => [
                'pending' => (clone $pending)->count(),
                'due' => $speak['mistakes_due'],
                'mastered' => $speak['mistakes_mastered'],
                'by_category' => $byCategory,
                'recent' => (clone $pending)->latest('id')->limit(5)->get()->map->toCard()->values(),
            ],
        ];

        return $data + ['todo' => $this->todo($data)];
    }

    /** Lo que conviene hacer hoy (máx. 4), de lo más importante a lo menos. */
    public function todo(array $d): array
    {
        $out = [];
        $add = function (string $icon, string $text, ?string $action = null, ?string $arg = null) use (&$out) {
            $out[] = compact('icon', 'text', 'action', 'arg');
        };

        if ($d['vocab']['due'] > 0) {
            $add('🗂️', "Tienes {$d['vocab']['due']} ".($d['vocab']['due'] === 1 ? 'ficha' : 'fichas').' para repasar hoy.', 'cards');
        }
        $left = round($d['speaking']['goal'] - $d['speaking']['today'], 1);
        if ($left > 0) {
            $add('🎙️', 'Te faltan '.str_replace('.', ',', (string) $left).' min de hablar para tu meta de hoy.', 'speak');
        }
        if ($d['mistakes']['due'] > 0) {
            $add('🔁', "Repasa {$d['mistakes']['due']} ".($d['mistakes']['due'] === 1 ? 'error' : 'errores').' de tus conversaciones.', 'review');
        }
        if (! $d['speaking']['narrated_today']) {
            $add('🗣️', 'Haz la narración del día: un minuto hablando sin parar.', 'narrate');
        }
        $sound = collect($d['pronunciation']['sounds'])->first(fn ($s) => $s['due'] && $s['tier'] !== 'd');
        if ($sound) {
            $tier = $sound['tier'] === 'g' ? 'Guiado' : 'Práctica';
            $add('🎯', "El sonido /{$sound['phoneme']}/ sigue en {$tier}: haz su taller.", 'lab', $sound['phoneme']);
        }
        if (! empty($d['level']['exam_ready'])) {
            $add('🏆', "Ya puedes hacer el examen para subir a {$d['level']['next']}.", 'exam');
        }
        $top = $d['mistakes']['by_category'][0] ?? null;
        if ($top && $top['count'] >= 3 && $top['category'] !== 'other') {
            $add('🧭', "Tu error más repetido: {$top['label']} ({$top['count']}). Fíjate en eso al hablar.");
        }
        $reaction = $d['speaking']['reaction'];
        if ($reaction && end($reaction) > 3) {
            $add('⚡', 'Tardas más de 3 s en arrancar: activa «Respuesta rápida» en Hablar.', 'speak');
        }

        return array_slice($out, 0, 4);
    }
}
