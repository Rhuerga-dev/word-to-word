<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Support\Collection;

/**
 * Oído: la app dice una palabra que ya aprendiste (sin texto) y eliges qué significa, rápido.
 * Así tu "pool" de palabras se vuelve de oído: la reconoces al escucharla, sin traducir.
 * Una palabra es "automática" cuando la reconociste rápido varias veces, espaciadas en el tiempo.
 */
class EarService
{
    /** Rápido = sin traducir mentalmente. */
    public const FAST_MS = 3000;

    /** Reconocida rápido estas veces seguidas (espaciadas) = automática. */
    public const AUTOMATIC_LEVEL = 3;

    public function __construct(private SrsService $srs) {}

    /** Lo que significa la palabra según el escalón: en español solo en el escalón 1. */
    public static function meaning(Word $w, int $spanishStep): string
    {
        $tr = trim(preg_split('/[;,\/]/', (string) $w->translation)[0] ?? '');
        if ($spanishStep >= 2 && filled($w->definition)) {
            return (string) $w->definition;
        }

        return $tr !== '' ? $tr : (string) $w->definition;
    }

    /** Las palabras que tocan hoy por oído (las menos automáticas primero), con 3 opciones cada una. */
    public function due(User $user, int $limit, int $spanishStep): Collection
    {
        $today = $this->srs->today($user)->toDateString();
        $due = UserWord::with('word')->where('user_id', $user->id)->whereNotNull('introduced_at')
            ->where(fn ($q) => $q->whereNull('ear_next')->orWhereDate('ear_next', '<=', $today))
            ->orderBy('ear_level')->orderBy('ear_next')->inRandomOrder()->limit($limit)->get()
            ->filter(fn (UserWord $uw) => $uw->word && self::meaning($uw->word, $spanishStep) !== '');
        if ($due->isEmpty()) {
            return collect();
        }

        // Opciones falsas: otras palabras tuyas (y si tienes pocas, otras comunes).
        $pool = UserWord::with('word')->where('user_id', $user->id)->whereNotNull('introduced_at')->inRandomOrder()->limit(40)->get()
            ->map(fn ($uw) => $uw->word)->filter();
        if ($pool->count() < 8) {
            $pool = $pool->concat(Word::whereNotNull('translation')->where('rank', '<=', 3000)->inRandomOrder()->limit(30)->get());
        }
        $pool = $pool->unique('id')->values();

        return $due->map(function (UserWord $uw) use ($pool, $spanishStep) {
            $w = $uw->word;
            $right = self::meaning($w, $spanishStep);
            $wrong = $pool->filter(fn (Word $o) => $o->id !== $w->id)
                ->map(fn (Word $o) => self::meaning($o, $spanishStep))
                ->filter(fn ($m) => $m !== '' && mb_strtolower($m) !== mb_strtolower($right))
                ->unique()->shuffle()->take(2)->values()->all();
            $options = collect([$right, ...$wrong])->shuffle()->values()->all();

            return [
                'id' => $w->id,
                'word' => $w->word,
                'example' => $w->example ? trim(str_replace('*', '', $w->example)) : null,
                'options' => $options,
                'answer' => array_search($right, $options, true),
                'ear_level' => (int) $uw->ear_level,
            ];
        })->values();
    }

    /**
     * Tu respuesta. Rápido y bien: sube y vuelve cada vez más tarde. Bien pero lento: vuelve mañana igual.
     * Mal: baja a cero y vuelve mañana.
     *
     * @return array{ear_level: int, automatic: bool, fast: bool, next: string}
     */
    public function answer(User $user, UserWord $uw, bool $ok, int $ms): array
    {
        $today = $this->srs->today($user);
        $fast = $ok && $ms <= self::FAST_MS;
        $intervals = config('vocab.intervals');
        if ($fast) {
            $uw->ear_level = min(255, $uw->ear_level + 1);
            $next = $today->addDays($intervals[min($uw->ear_level - 1, count($intervals) - 1)]);
        } else {
            if (! $ok) {
                $uw->ear_level = 0;
            }
            $next = $today->addDay();
        }
        $uw->ear_next = $next->toDateString();
        $uw->ear_ms = max(0, min($ms, 60000));
        $uw->save();

        return ['ear_level' => (int) $uw->ear_level, 'automatic' => $uw->ear_level >= self::AUTOMATIC_LEVEL, 'fast' => $fast, 'next' => $next->toDateString()];
    }

    public function automaticCount(User $user): int
    {
        return UserWord::where('user_id', $user->id)->where('ear_level', '>=', self::AUTOMATIC_LEVEL)->count();
    }
}
