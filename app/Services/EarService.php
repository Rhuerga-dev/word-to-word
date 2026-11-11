<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Support\Collection;

/**
 * Oído: reconocer de oído las palabras que ya aprendiste. Cada palabra sube por escalones,
 * de lo más fácil a lo más difícil, y siempre en inglés:
 *
 *   0 · sound       oyes la palabra despacio y eliges cuál de 3 palabras ESCRITAS oíste (sonidos parecidos)
 *   1 · easy        oyes la palabra y eliges su significado más simple (emoji + 1–3 palabras básicas)
 *   2 · definition  eliges la definición escrita solo con palabras muy comunes
 *   3 · sentence    oyes una frase que la contiene (y luego la palabra) y eliges el significado
 *   4 · fast        igual, pero tienes 2 segundos
 *   5+              automática: la reconoces sin pensar
 *
 * Rápido y bien: sube un escalón y vuelve más tarde. Bien pero lento: mañana, mismo escalón.
 * Mal: baja un escalón (no a cero) y vuelve mañana.
 */
class EarService
{
    public const MODES = ['sound', 'easy', 'definition', 'sentence', 'fast'];

    /** Tiempo para contar como "rápido" (sin traducir), por escalón. */
    public const FAST_MS = [3500, 3000, 3500, 3500, 2000];

    /** Desde aquí la palabra es "automática". */
    public const AUTOMATIC_LEVEL = 5;

    public function __construct(private SrsService $srs) {}

    public static function mode(int $level): string
    {
        return self::MODES[min($level, count(self::MODES) - 1)];
    }

    public static function fastMs(int $level): int
    {
        return self::FAST_MS[min($level, count(self::FAST_MS) - 1)];
    }

    /** Significado muy simple: emoji + 1–3 palabras (o, si aún no lo hay, la definición fácil). */
    public static function easy(Word $w): string
    {
        $g = trim((string) $w->gloss);
        if ($g !== '') {
            return trim(($w->emoji ? $w->emoji.' ' : '').$g);
        }

        return self::definition($w);
    }

    /** Definición con palabras muy comunes (o la normal si aún no la hay). */
    public static function definition(Word $w): string
    {
        return trim((string) ($w->definition_easy ?: $w->definition));
    }

    private static function meaning(Word $w, string $mode): string
    {
        return $mode === 'easy' ? self::easy($w) : self::definition($w);
    }

    /** Las palabras que tocan hoy por oído (las de escalón más bajo primero), listas para la app. */
    public function due(User $user, int $limit): Collection
    {
        $today = $this->srs->today($user)->toDateString();
        $due = UserWord::with('word')->where('user_id', $user->id)->whereNotNull('introduced_at')
            ->where(fn ($q) => $q->whereNull('ear_next')->orWhereDate('ear_next', '<=', $today))
            ->orderBy('ear_level')->orderBy('ear_next')->inRandomOrder()->limit($limit * 2)->get()
            ->filter(fn (UserWord $uw) => $uw->word !== null);
        if ($due->isEmpty()) {
            return collect();
        }

        // Para las opciones falsas: otras palabras tuyas (y si tienes pocas, otras comunes).
        $pool = UserWord::with('word')->where('user_id', $user->id)->whereNotNull('introduced_at')->inRandomOrder()->limit(40)->get()
            ->map(fn ($uw) => $uw->word)->filter();
        if ($pool->count() < 8) {
            $pool = $pool->concat(Word::whereNotNull('translation')->where('rank', '<=', 3000)->inRandomOrder()->limit(30)->get());
        }
        $pool = $pool->unique('id')->values();

        return $due->map(fn (UserWord $uw) => $this->item($uw, $pool))->filter()->take($limit)->values();
    }

    private function item(UserWord $uw, Collection $pool): ?array
    {
        $w = $uw->word;
        $level = (int) $uw->ear_level;
        $mode = self::mode($level);
        $example = $w->example ? trim(str_replace('*', '', $w->example)) : null;
        if (in_array($mode, ['sentence', 'fast'], true) && ! $example) {
            $mode = 'definition'; // sin frase de ejemplo, se queda en la definición
        }

        if ($mode === 'sound') {
            $options = collect([$w->word, ...$this->soundAlikes($w->word)])->shuffle()->values()->all();
            $right = $w->word;
        } else {
            $kind = $mode === 'easy' ? 'easy' : 'definition';
            $right = self::meaning($w, $kind);
            if ($right === '') {
                return null;
            }
            $wrong = $pool->filter(fn (Word $o) => $o->id !== $w->id)
                ->map(fn (Word $o) => self::meaning($o, $kind))
                ->filter(fn ($m) => $m !== '' && mb_strtolower($m) !== mb_strtolower($right))
                ->unique()->shuffle()->take(2)->values()->all();
            if (count($wrong) < 2) {
                return null;
            }
            $options = collect([$right, ...$wrong])->shuffle()->values()->all();
        }

        // Lo que suena: la palabra (despacio al principio) o la frase y luego la palabra.
        $audio = in_array($mode, ['sentence', 'fast'], true)
            ? [['text' => $example, 'slow' => false], ['text' => $w->word, 'slow' => false]]
            : [['text' => $w->word, 'slow' => $mode === 'sound']];

        return [
            'id' => $w->id,
            'word' => $w->word,
            'mode' => $mode,
            'audio' => $audio,
            'example' => $example,
            'options' => $options,
            'answer' => array_search($right, $options, true),
            'ear_level' => $level,
            'fast_ms' => self::fastMs($level),
        ];
    }

    /**
     * Dos palabras que suenan parecido (mismo principio o mismo final, poca diferencia).
     *
     * @return array<int, string>
     */
    public function soundAlikes(string $word): array
    {
        $w = mb_strtolower($word);
        $len = mb_strlen($w);
        $cands = Word::query()
            ->where(fn ($q) => $q->where('word', 'like', mb_substr($w, 0, 2).'%')->orWhere('word', 'like', '%'.mb_substr($w, -3)))
            ->whereRaw('length(word) between ? and ?', [max(2, $len - 2), $len + 2])
            ->where('rank', '<=', 8000)->limit(300)->pluck('word')
            ->map(fn ($c) => mb_strtolower($c))->filter(fn ($c) => $c !== $w && preg_match('/^[a-z]+$/', $c))->unique()
            ->sortBy(fn ($c) => levenshtein($w, $c))->values();
        $picked = $cands->take(2)->all();
        if (count($picked) < 2) {
            $picked = array_merge($picked, Word::where('rank', '<=', 2000)->whereRaw('length(word) between ? and ?', [max(2, $len - 1), $len + 1])
                ->where('word', '!=', $word)->inRandomOrder()->limit(2 - count($picked))->pluck('word')->map(fn ($c) => mb_strtolower($c))->all());
        }

        return array_values($picked);
    }

    /**
     * @return array{ear_level: int, automatic: bool, fast: bool, next: string, mode: string}
     */
    public function answer(User $user, UserWord $uw, bool $ok, int $ms): array
    {
        $today = $this->srs->today($user);
        $level = (int) $uw->ear_level;
        $fast = $ok && $ms <= self::fastMs($level);
        $intervals = config('vocab.intervals');
        if ($fast) {
            $uw->ear_level = min(255, $level + 1);
            $next = $today->addDays($intervals[min($level, count($intervals) - 1)]);
        } else {
            if (! $ok) {
                $uw->ear_level = max(0, $level - 1);
            }
            $next = $today->addDay();
        }
        $uw->ear_next = $next->toDateString();
        $uw->ear_ms = max(0, min($ms, 60000));
        $uw->save();

        return [
            'ear_level' => (int) $uw->ear_level,
            'mode' => self::mode((int) $uw->ear_level),
            'automatic' => $uw->ear_level >= self::AUTOMATIC_LEVEL,
            'fast' => $fast,
            'next' => $next->toDateString(),
        ];
    }

    public function automaticCount(User $user): int
    {
        return UserWord::where('user_id', $user->id)->where('ear_level', '>=', self::AUTOMATIC_LEVEL)->count();
    }

    /** Una palabra de una definición que no entiendes: su significado más simple. */
    public static function lookup(string $text, ?ClaudeService $claude = null): ?array
    {
        $t = mb_strtolower(trim(preg_replace('/[^\p{L}\'-]/u', '', $text)));
        if ($t === '') {
            return null;
        }
        $w = Word::whereRaw('lower(word) = ?', [$t])->first();
        // Plurales y verbos sencillos: books → book, walked → walk, making → make.
        if (! $w) {
            foreach ([preg_replace('/(ies)$/', 'y', $t), preg_replace('/(es|s)$/', '', $t), preg_replace('/(ed|d)$/', '', $t), preg_replace('/ing$/', '', $t), preg_replace('/ing$/', 'e', $t)] as $alt) {
                if ($alt && $alt !== $t && ($w = Word::whereRaw('lower(word) = ?', [$alt])->first())) {
                    break;
                }
            }
        }
        if (! $w) {
            return null;
        }
        // Aún sin significado fácil: la IA lo escribe ahora y queda guardado para todos.
        if ($w->gloss === null && $claude && $claude->enabled()) {
            try {
                $m = $claude->simplify([$w->word])[$w->word] ?? null;
                $leaks = fn (?string $s) => $s !== null && preg_match('/\b'.preg_quote(mb_strtolower($w->word), '/').'/u', mb_strtolower($s));
                if ($m) {
                    $w->update([
                        'gloss' => $m['gloss'] && ! $leaks($m['gloss']) ? mb_substr($m['gloss'], 0, 60) : '',
                        'emoji' => $m['emoji'] ? mb_substr($m['emoji'], 0, 16) : null,
                        'definition_easy' => $m['easy'] && ! $leaks($m['easy']) ? mb_substr($m['easy'], 0, 255) : $w->definition_easy,
                    ]);
                }
            } catch (\Throwable $e) {
                report($e);
            }
        }
        $easy = trim((string) $w->gloss);

        $out = ['word' => $w->word, 'emoji' => $w->emoji, 'gloss' => $easy !== '' ? $easy : null, 'easy' => self::definition($w) ?: null];

        return $out['gloss'] || $out['easy'] ? $out : null;
    }
}
