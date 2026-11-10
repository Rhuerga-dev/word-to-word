<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Niveles MCER (A1..C1) sobre la lista de palabras ordenada por frecuencia.
 * Cada nivel es un tramo de la lista general (sin el paquete de freelance).
 */
class LevelService
{
    public const FREELANCE = 'freelance';

    public const FAMILY = 'family';

    /** Palabras que un alumno agregó (p. ej. las que le faltaron al describir una foto): solo son suyas. */
    public const PERSONAL = 'personal';

    /** @var array<string, array{min:int|null, max:int|null}> */
    private array $rangeCache = [];

    /** @return list<string> */
    public function codes(): array
    {
        return array_keys(config('vocab.levels'));
    }

    public function next(string $level): ?string
    {
        $codes = $this->codes();
        $i = array_search($level, $codes, true);

        return $i === false ? null : ($codes[$i + 1] ?? null);
    }

    /** Palabras generales (sin el paquete de freelance ni las agregadas solo por familia). */
    public function general(): Builder
    {
        return Word::query()->whereNotIn('source', [self::FREELANCE, self::FAMILY, self::PERSONAL]);
    }

    /** Palabras listas para estudiar (con traducción y ejemplo). */
    public function ready(Builder $q): Builder
    {
        return $q->whereNotNull('translation')->whereNotNull('example');
    }

    /**
     * Rango de "rank" que cubre un nivel. min null = no hay palabras importadas
     * para ese nivel todavía.
     *
     * @return array{min:int|null, max:int|null}
     */
    public function range(string $level): array
    {
        if (isset($this->rangeCache[$level])) {
            return $this->rangeCache[$level];
        }
        $cfg = config("vocab.levels.$level");
        $rankAt = fn (int $pos) => $this->general()->orderBy('rank')->skip($pos - 1)->value('rank');

        $min = $rankAt($cfg['from']);
        $max = $min === null ? null : ($rankAt($cfg['to']) ?? $this->general()->max('rank'));

        return $this->rangeCache[$level] = ['min' => $min, 'max' => $max];
    }

    /** Palabras generales de un nivel. */
    public function inLevel(string $level): Builder
    {
        ['min' => $min, 'max' => $max] = $this->range($level);
        $q = $this->general();

        return $min === null ? $q->whereRaw('1 = 0') : $q->whereBetween('rank', [$min, $max]);
    }

    /** Progreso del usuario en su nivel actual. */
    public function progress(User $user): array
    {
        $level = $user->cefr_level;
        if (! $level) {
            return ['level' => null];
        }

        $ids = $this->ready($this->inLevel($level))->pluck('id');
        $total = $ids->count();
        $learned = UserWord::where('user_id', $user->id)->whereIn('word_id', $ids)->whereNotNull('introduced_at');
        $introduced = (clone $learned)->count();
        $mastered = (clone $learned)->where('level', '>=', config('vocab.mastered_level'))->count();
        $coverage = $total ? $introduced / $total : 0;
        $next = $this->next($level);

        return [
            'level' => $level,
            'name' => config("vocab.levels.$level.name"),
            'can' => config("vocab.levels.$level.can"),
            'next' => $next,
            'total' => $total,
            'introduced' => $introduced,
            'mastered' => $mastered,
            'coverage' => round($coverage, 3),
            'exam_ready' => $next !== null && $total > 0 && $coverage >= config('vocab.level_exam_coverage'),
            'exam_needed' => (int) ceil($total * config('vocab.level_exam_coverage')),
        ];
    }

    /** Todos los niveles con su tamaño, para mostrar el camino completo. */
    public function overview(): array
    {
        return collect(config('vocab.levels'))->map(fn ($cfg, $code) => [
            'code' => $code,
            'name' => $cfg['name'],
            'can' => $cfg['can'],
            'words' => $this->ready($this->inLevel($code))->count(),
        ])->values()->all();
    }

    // ---------- Prueba de nivel inicial ----------

    /** Preguntas de opción múltiple: unas pocas palabras de cada nivel. */
    public function placementQuestions(): array
    {
        $per = (int) config('vocab.placement_per_level');
        $out = [];
        foreach ($this->codes() as $code) {
            $words = $this->ready($this->inLevel($code))->inRandomOrder()->limit($per)->get();
            foreach ($words as $w) {
                $out[] = $this->question($w, $code);
            }
        }

        return $out;
    }

    /**
     * Califica la prueba inicial. Un nivel se da por dominado si se acierta el
     * % mínimo; el usuario empieza en el primer nivel no dominado.
     *
     * @param  array<int, array{word_id:int, answer:string}>  $answers
     */
    public function gradePlacement(User $user, array $answers): array
    {
        $graded = $this->grade($answers);
        $byLevel = [];
        foreach ($graded as $g) {
            $level = $this->levelOf($g['word']);
            if ($level) {
                $byLevel[$level][] = $g['correct'];
            }
        }

        $start = $this->codes()[0];
        foreach ($this->codes() as $code) {
            $res = $byLevel[$code] ?? [];
            $passed = count($res) > 0 && array_sum($res) / count($res) >= config('vocab.placement_pass');
            if (! $passed) {
                $start = $code;
                break;
            }
            // Dominó este nivel: empieza en el siguiente (o se queda en el último).
            $start = $this->next($code) ?? $code;
        }

        $score = $graded->count() ? (int) round($graded->where('correct', true)->count() / $graded->count() * 100) : 0;

        DB::transaction(function () use ($user, $start, $score) {
            $user->forceFill(['cefr_level' => $start])->save();
            DB::table('level_results')->insert([
                'user_id' => $user->id, 'kind' => 'placement', 'level' => $start,
                'score' => $score, 'passed' => true, 'new_level' => $start,
                'created_at' => now(), 'updated_at' => now(),
            ]);
        });

        return [
            'level' => $start,
            'score' => $score,
            'by_level' => collect($byLevel)->map(fn ($r) => (int) round(array_sum($r) / count($r) * 100))->all(),
        ];
    }

    // ---------- Examen para subir de nivel ----------

    public function examQuestions(User $user): array
    {
        $level = $user->cefr_level;
        $size = (int) config('vocab.level_exam_size');

        // Preferimos palabras que el usuario ya estudió.
        $studied = UserWord::where('user_id', $user->id)->whereNotNull('introduced_at')->pluck('word_id');
        $words = $this->ready($this->inLevel($level))->whereIn('id', $studied)->inRandomOrder()->limit($size)->get();
        if ($words->count() < $size) {
            $more = $this->ready($this->inLevel($level))->whereNotIn('id', $words->pluck('id'))
                ->inRandomOrder()->limit($size - $words->count())->get();
            $words = $words->concat($more);
        }

        return $words->shuffle()->map(fn (Word $w) => $this->question($w, $level))->values()->all();
    }

    /** @param  array<int, array{word_id:int, answer:string}>  $answers */
    public function gradeExam(User $user, array $answers): array
    {
        $level = $user->cefr_level;
        $graded = $this->grade($answers)->filter(fn ($g) => $this->levelOf($g['word']) === $level);
        $score = $graded->count() ? (int) round($graded->where('correct', true)->count() / $graded->count() * 100) : 0;
        $passed = $graded->count() >= min(5, (int) config('vocab.level_exam_size'))
            && $score >= config('vocab.level_exam_pass') * 100;
        $newLevel = $passed ? ($this->next($level) ?? $level) : $level;

        DB::transaction(function () use ($user, $level, $score, $passed, $newLevel) {
            if ($passed) {
                $user->forceFill(['cefr_level' => $newLevel])->save();
            }
            DB::table('level_results')->insert([
                'user_id' => $user->id, 'kind' => 'exam', 'level' => $level,
                'score' => $score, 'passed' => $passed, 'new_level' => $passed ? $newLevel : null,
                'created_at' => now(), 'updated_at' => now(),
            ]);
        });

        return [
            'passed' => $passed,
            'score' => $score,
            'level' => $newLevel,
            'missed' => $graded->where('correct', false)->map(fn ($g) => [
                'word' => $g['word']->word,
                'translation' => $g['word']->translation,
            ])->values()->all(),
        ];
    }

    public function history(User $user): Collection
    {
        return DB::table('level_results')->where('user_id', $user->id)
            ->orderByDesc('created_at')->orderByDesc('id')->limit(20)
            ->get(['kind', 'level', 'score', 'passed', 'new_level', 'created_at']);
    }

    // ---------- helpers ----------

    public function levelOf(Word $word): ?string
    {
        if ($word->source === self::FREELANCE) {
            return null;
        }
        foreach ($this->codes() as $code) {
            ['min' => $min, 'max' => $max] = $this->range($code);
            if ($min !== null && $word->rank >= $min && $word->rank <= $max) {
                return $code;
            }
        }

        return null;
    }

    /** Pregunta con 4 opciones de traducción; la correcta no se marca. */
    private function question(Word $word, string $level): array
    {
        $distractors = $this->ready($this->inLevel($level))
            ->where('id', '!=', $word->id)
            ->where('translation', '!=', $word->translation)
            ->inRandomOrder()->limit(3)->pluck('translation');
        if ($distractors->count() < 3) {
            $distractors = $distractors->concat(
                $this->ready(Word::query())->where('id', '!=', $word->id)
                    ->where('translation', '!=', $word->translation)
                    ->whereNotIn('translation', $distractors)
                    ->inRandomOrder()->limit(3 - $distractors->count())->pluck('translation')
            );
        }

        return [
            'word_id' => $word->id,
            'word' => $word->word,
            'example' => $word->example,
            'options' => $distractors->push($word->translation)->unique()->shuffle()->values()->all(),
        ];
    }

    /**
     * @param  array<int, array{word_id:int, answer:string}>  $answers
     * @return Collection<int, array{word: Word, correct: bool}>
     */
    private function grade(array $answers): Collection
    {
        $byId = collect($answers)->keyBy('word_id');
        $words = Word::whereIn('id', $byId->keys())->get();

        return $words->map(fn (Word $w) => [
            'word' => $w,
            'correct' => trim(mb_strtolower((string) $byId[$w->id]['answer'])) === trim(mb_strtolower((string) $w->translation)),
        ])->values();
    }
}
