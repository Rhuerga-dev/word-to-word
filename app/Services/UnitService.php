<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/** Camino: unidades del nivel del alumno, sus pasos y qué está desbloqueado. */
class UnitService
{
    /** Palabras creadas para unidades (no salen como "nuevas" fuera de su unidad). */
    public const SOURCE = 'unit';

    public function __construct(private SrsService $srs) {}

    /** @return array<int, array> unidades del nivel (en orden) */
    public function units(?string $level): array
    {
        return config("units.levels.{$level}", []);
    }

    public function find(string $id): ?array
    {
        foreach (config('units.levels', []) as $level => $units) {
            foreach ($units as $u) {
                if ($u['id'] === $id) {
                    return $u + ['level' => $level];
                }
            }
        }

        return null;
    }

    /** Palabras de la unidad listas para estudiar (con traducción y ejemplo), en el orden de la lista. */
    public function words(array $unit): Collection
    {
        $q = Word::query()->whereNotNull('translation')->whereNotNull('example');
        $listed = (clone $q)->whereIn('word', $unit['words'] ?? [])->get()
            ->sortBy(fn (Word $w) => array_search($w->word, $unit['words']))->values();
        $extra = collect();
        if (! empty($unit['family'])) {
            $extra = $extra->concat((clone $q)->where('category', $unit['family'])->orderBy('rank')->limit(12)->get());
        }
        if (! empty($unit['source'])) {
            $extra = $extra->concat((clone $q)->where('source', $unit['source'])->orderBy('rank')->limit(12)->get());
        }

        return $listed->concat($extra)->unique('id')->values();
    }

    /** Estado de cada unidad del nivel del alumno: pasos hechos y si está abierta. */
    public function path(User $user): array
    {
        $level = $user->cefr_level;
        $units = $this->units($level);
        $rows = DB::table('unit_progress')->where('user_id', $user->id)->get()->keyBy('unit');
        $introduced = UserWord::where('user_id', $user->id)->whereNotNull('introduced_at')->pluck('word_id')->flip();
        $sounds = DB::table('phoneme_errors')->where('user_id', $user->id)->get()->keyBy('phoneme');
        $target = (int) config('units.words_target', 8);

        $out = [];
        $previousDone = true;
        foreach ($units as $i => $u) {
            $u = $this->forProfession($u, $user->profession);
            $row = $rows[$u['id']] ?? null;
            $words = $this->words($u);
            $need = min($target, $words->count());
            $learned = $words->filter(fn (Word $w) => isset($introduced[$w->id]))->count();
            $snd = $sounds[$u['sound']] ?? null;
            $steps = [
                'words' => $need === 0 || $learned >= $need,
                'sound' => $snd && ((int) $snd->stage >= 1 || in_array($snd->tier ?? 'g', ['p', 'd'], true) || $snd->mastered_on),
                'shadow' => (bool) ($row->shadow_at ?? false),
            ];
            $done = (bool) ($row->passed_at ?? false);
            $open = $previousDone || $done;
            $out[] = [
                'id' => $u['id'],
                'number' => $i + 1,
                'title' => $u['title'],
                'icon' => $u['icon'] ?? null,
                'state' => $done ? 'done' : ($open ? 'open' : 'locked'),
                'words' => ['learned' => min($learned, $need), 'need' => $need, 'preview' => $words->take(4)->pluck('word')->all()],
                'sound' => $u['sound'],
                'scenario' => $u['scenario'],
                'scenario_title' => config("speaking.scenarios.{$u['scenario']}.title"),
                'steps' => $steps + ['test' => $done],
                'test_ready' => $steps['words'] && $steps['sound'] && $steps['shadow'],
                'test' => ['score' => $row->test_score ?? null, 'tries' => (int) ($row->test_tries ?? 0), 'feedback' => $row->test_feedback ?? null],
            ];
            $previousDone = $done;
        }
        $current = collect($out)->first(fn ($u) => $u['state'] === 'open');

        return [
            'level' => $level,
            'level_name' => config("vocab.levels.{$level}.name"),
            'units' => $out,
            'current' => $current['id'] ?? null,
            'completed' => collect($out)->where('state', 'done')->count(),
        ];
    }

    /** La unidad adaptada a la profesión: otra conversación y, si la unidad trae "alt", su título y palabras. */
    public function forProfession(array $u, ?string $profession): array
    {
        $scenario = \App\Support\Professions::scenarioFor($profession, $u['scenario']);
        if ($scenario === $u['scenario']) {
            return $u;
        }
        $alt = $u['alt'] ?? [];
        unset($u['alt']);
        if (isset($alt['words'])) {
            unset($u['source'], $u['family']);
        }

        return array_merge($u, $alt, ['scenario' => $scenario]);
    }

    /** ¿Puede el alumno trabajar en esta unidad? (de su nivel y desbloqueada) */
    public function openFor(User $user, string $id): ?array
    {
        $unit = collect($this->path($user)['units'])->firstWhere('id', $id);

        return $unit && $unit['state'] !== 'locked' ? $unit : null;
    }

    public function progress(User $user, string $unit): object
    {
        DB::table('unit_progress')->insertOrIgnore(['user_id' => $user->id, 'unit' => $unit, 'created_at' => now(), 'updated_at' => now()]);

        return DB::table('unit_progress')->where('user_id', $user->id)->where('unit', $unit)->first();
    }
}
