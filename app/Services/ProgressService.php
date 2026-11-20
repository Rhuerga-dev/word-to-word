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
        $labels = \App\Support\CoursePack::get('speaking.mistake_categories');
        $pending = SpeakingMistake::where('user_id', $user->id)->whereNull('mastered_on');
        $byCategory = (clone $pending)->selectRaw("coalesce(category, 'other') as cat, count(*) as n")->groupBy('cat')
            ->orderByDesc('n')->get()
            ->map(fn ($r) => ['category' => $r->cat, 'label' => \App\Support\Ui::t((string) ($labels[$r->cat] ?? $labels['other'])), 'count' => (int) $r->n])->values();

        $level = $this->levels->progress($user);
        $data = [
            'today' => $today->toDateString(),
            'vocab' => [
                'learned' => $srsStats['learned'],
                'mastered' => $srsStats['mastered'],
                'total' => $srsStats['total_words'],
                'streak' => $srsStats['streak'],
                'streak_freezes' => $srsStats['streak_freezes'],
                'streak_protected' => $srsStats['streak_protected'],
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

        $data['spanish'] = app(SpanishService::class)->summary($user);

        return $data + ['todo' => $this->todo($data)];
    }

    /** Lo que conviene hacer hoy (máx. 4), de lo más importante a lo menos. */
    public function todo(array $d): array
    {
        $out = [];
        $add = function (string $icon, string $text, ?string $action = null, ?string $arg = null) use (&$out) {
            $out[] = compact('icon', 'text', 'action', 'arg');
        };

        $t = fn (string $es, array $args = []) => \App\Support\Ui::t($es, $args);   // en el idioma del alumno
        if ($d['vocab']['due'] > 0) {
            $add('🗂️', $d['vocab']['due'] === 1 ? $t('Tienes 1 ficha para repasar hoy.') : $t('Tienes :n fichas para repasar hoy.', ['n' => $d['vocab']['due']]), 'cards');
        }
        $left = round($d['speaking']['goal'] - $d['speaking']['today'], 1);
        if ($left > 0) {
            $add('🎙️', $t('Te faltan :n min de hablar para tu meta de hoy.', ['n' => str_replace('.', ',', (string) $left)]), 'speak');
        }
        if ($d['mistakes']['due'] > 0) {
            $add('🔁', $d['mistakes']['due'] === 1 ? $t('Repasa 1 error de tus conversaciones.') : $t('Repasa :n errores de tus conversaciones.', ['n' => $d['mistakes']['due']]), 'review');
        }
        // La narración solo se propone si la clase de este curso la tiene (el de español aún no).
        $steps = \App\Support\CoursePack::get('session.steps');
        if (! $d['speaking']['narrated_today'] && ($steps === null || in_array('narrate', (array) $steps, true))) {
            $add('🗣️', $t('Haz la narración del día: un minuto hablando sin parar.'), 'narrate');
        }
        $sound = collect($d['pronunciation']['sounds'])->first(fn ($s) => $s['due'] && $s['tier'] !== 'd');
        if ($sound) {
            $tier = $t($sound['tier'] === 'g' ? 'Guiado' : 'Práctica');
            $add('🎯', $t('El sonido /:sound/ sigue en :tier: haz su taller.', ['sound' => $sound['phoneme'], 'tier' => $tier]), 'lab', $sound['phoneme']);
        }
        if (! empty($d['level']['exam_ready'])) {
            $add('🏆', $t('Ya puedes hacer el examen para subir a :level.', ['level' => $d['level']['next']]), 'exam');
        }
        $top = $d['mistakes']['by_category'][0] ?? null;
        if ($top && $top['count'] >= 3 && $top['category'] !== 'other') {
            $add('🧭', $t('Tu error más repetido: :label (:n). Fíjate en eso al hablar.', ['label' => $top['label'], 'n' => $top['count']]));
        }
        $sp = $d['spanish'] ?? null;
        if ($sp && $sp['step'] >= 2 && $sp['today'] > 0 && \App\Support\Ui::lang() === 'es') {   // solo en el curso de inglés
            $add('🇪🇸', $sp['today'] === 1 ? $t('Hoy pediste español 1 vez. Mañana intenta explicarlo en inglés con otras palabras.') : $t('Hoy pediste español :n veces. Mañana intenta explicarlo en inglés con otras palabras.', ['n' => $sp['today']]));
        }
        $reaction = $d['speaking']['reaction'];
        if ($reaction && end($reaction) > 3) {
            $add('⚡', $t('Tardas más de 3 s en arrancar: activa «Respuesta rápida» en Hablar.'), 'speak');
        }

        return array_slice($out, 0, 4);
    }
}
