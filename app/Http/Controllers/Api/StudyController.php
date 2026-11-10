<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\ClaudeService;
use App\Services\PronunciationService;
use App\Services\LevelService;
use App\Services\SrsService;
use App\Services\XpService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class StudyController extends Controller
{
    public function __construct(private SrsService $srs) {}

    /** Qué servicios externos están configurados (el frontend se adapta). */
    public function config(ClaudeService $claude, PronunciationService $pron)
    {
        return [
            'ai' => $claude->enabled(),
            'pronunciation' => $pron->enabled(),
            'time_travel' => config('vocab.allow_time_travel'),
            'push' => filled(config('webpush.vapid.public_key')),
            'tts' => app(\App\Services\TtsService::class)->enabled(),
            'intervals' => config('vocab.intervals'),
            'tts_local' => filled(config('vocab.tts.local_url')),
            'pictures' => app(\App\Services\PictureService::class)->enabled(),
        ];
    }

    /** La sesión de hoy: primero repasos, luego palabras nuevas. */
    public function today(Request $request)
    {
        $user = $request->user();
        $q = $this->srs->queue($user);

        // Repasos agrupados por familia: las palabras del mismo tema van seguidas.
        $reviews = $q['reviews']->groupBy(fn (UserWord $uw) => $uw->word->category ?? '')->flatten(1);

        $cards = $reviews->map(fn (UserWord $uw) => $this->card($uw->word, $uw, 'review'))
            ->concat($q['new']->map(fn (Word $w) => $this->card($w, null, 'new')))
            ->values();

        return [
            'today' => $this->srs->today($user)->toDateString(),
            'daily_new' => $user->daily_new,
            'new_done' => $q['new_done'],
            'cards' => $cards,
        ];
    }

    public function stats(Request $request)
    {
        return $this->srs->stats($request->user());
    }

    public function settings(Request $request)
    {
        $data = $request->validate([
            'daily_new' => ['sometimes', 'integer', 'min:1', 'max:50'],
            'freelance_pack' => ['sometimes', 'boolean'],
            'family' => ['sometimes', 'nullable', Rule::in(array_keys(config('vocab.families')))],
            'xp_goal' => ['sometimes', 'integer', 'min:20', 'max:500'],
        ]);
        $request->user()->update($data);

        return $request->user()->profile();
    }

    /**
     * Agrega una palabra a tus fichas (p. ej. una que te faltó al describir una foto).
     * Si no existe, se crea como palabra personal: nunca aparece como "nueva" a otros alumnos.
     */
    public function addPersonal(Request $request)
    {
        $data = $request->validate([
            'word' => ['required', 'string', 'max:40', "regex:/^[A-Za-z][A-Za-z' -]*$/"],
            'translation' => ['required', 'string', 'max:120'],
            'example' => ['required', 'string', 'max:200'],
        ]);
        $user = $request->user();
        $text = mb_strtolower(trim($data['word']));
        // El ejemplo lleva la palabra entre *asteriscos* (si no, se marca la primera vez que aparece).
        $example = str_contains($data['example'], '*') ? $data['example']
            : (preg_replace('/\b('.preg_quote($text, '/').')\b/i', '*$1*', $data['example'], 1) ?? $data['example']);

        $word = Word::firstOrCreate(['word' => $text], [
            'rank' => 900000, 'source' => LevelService::PERSONAL,
            'translation' => $data['translation'], 'example' => $example,
        ]);
        $uw = UserWord::firstOrNew(['user_id' => $user->id, 'word_id' => $word->id]);
        $already = (bool) $uw->introduced_at;
        if (! $already) {
            $today = $this->srs->today($user);
            $uw->fill(['level' => 0, 'introduced_at' => $today, 'next_review' => $today->addDay()])->save();
        }

        return ['word' => $word->word, 'id' => $word->id, 'added' => ! $already];
    }

    /** Familias de palabras con el progreso del usuario en cada una. */
    public function families(Request $request)
    {
        $user = $request->user();
        $levels = app(\App\Services\LevelService::class);
        $totals = $levels->ready(Word::query()->whereNotNull('category'))
            ->selectRaw('category, count(*) as n')->groupBy('category')->pluck('n', 'category');
        $mine = DB::table('user_words')->join('words', 'words.id', '=', 'user_words.word_id')
            ->where('user_words.user_id', $user->id)->whereNotNull('user_words.introduced_at')->whereNotNull('words.category')
            ->selectRaw('words.category, count(*) as learned, sum(case when user_words.level >= ? then 1 else 0 end) as mastered', [config('vocab.mastered_level')])
            ->groupBy('words.category')->get()->keyBy('category');

        return [
            'current' => $user->family,
            'families' => collect(config('vocab.families'))->map(fn ($f, $key) => [
                'key' => $key, 'label' => $f['label'], 'emoji' => $f['emoji'],
                'total' => (int) ($totals[$key] ?? 0),
                'learned' => (int) ($mine[$key]->learned ?? 0),
                'mastered' => (int) ($mine[$key]->mastered ?? 0),
            ])->filter(fn ($f) => $f['total'] > 0)->values(),
        ];
    }

    public function learn(Request $request, Word $word, XpService $xp)
    {
        $user = $request->user();
        $before = UserWord::where('user_id', $user->id)->where('word_id', $word->id)->whereNotNull('introduced_at')->exists();
        $uw = $this->srs->learn($user, $word);
        $gained = $before ? 0 : $xp->add($user, 'learn');

        return $this->card($word, $uw, 'review') + ['xp_gained' => $gained];
    }

    public function review(Request $request, Word $word, XpService $xp)
    {
        $data = $request->validate(['grade' => ['required', Rule::in(SrsService::GRADES)]]);
        $uw = $this->userWord($request, $word, mustBeIntroduced: true);
        $uw = $this->srs->review($request->user(), $uw, $data['grade']);
        $gained = $xp->add($request->user(), $data['grade'] === 'again' ? 'review_again' : 'review');

        return $this->card($word, $uw, 'review') + ['xp_gained' => $gained];
    }

    /** Solo para probar: adelanta el "hoy" del usuario un día. */
    public function nextDay(Request $request)
    {
        abort_unless(config('vocab.allow_time_travel'), 403, 'Desactivado en este servidor.');
        $request->user()->increment('day_offset');

        return ['today' => $this->srs->today($request->user()->fresh())->toDateString()];
    }

    public function reset(Request $request)
    {
        $user = $request->user();
        DB::transaction(function () use ($user) {
            UserWord::where('user_id', $user->id)->delete();
            DB::table('study_days')->where('user_id', $user->id)->delete();
            DB::table('phoneme_errors')->where('user_id', $user->id)->delete();
            DB::table('level_results')->where('user_id', $user->id)->delete();
            DB::table('xp_days')->where('user_id', $user->id)->delete();
            DB::table('unit_progress')->where('user_id', $user->id)->delete();
            DB::table('speaking_mistakes')->where('user_id', $user->id)->delete();
            DB::table('speaking_sessions')->where('user_id', $user->id)->delete();
            $user->forceFill(['xp_total' => 0, 'day_offset' => 0, 'streak' => 0, 'last_study_day' => null, 'cefr_level' => null])->save();
        });

        return response()->noContent();
    }

    // ---------- helpers ----------

    public static function cardFor(Word $word, ?UserWord $uw, string $mode, SrsService $srs): array
    {
        return [
            'id' => $word->id,
            'word' => $word->word,
            'rank' => $word->rank,
            'translation' => $word->translation,
            'example' => $word->example,
            'example_es' => $word->example_es,
            'definition' => $word->definition,
            // Ficha avanzada: se recuerda la palabra desde el inglés (definición + frase con hueco), sin traducir.
            'english_only' => $mode === 'review' && ($uw?->level ?? 0) >= config('vocab.english_only_level', 3)
                && str_contains((string) $word->example, '*'),
            'category' => $word->category,
            'family' => $word->family(),
            'mode' => $mode,
            'level' => $uw?->level ?? 0,
            'fails' => $uw?->fails ?? 0,
            'aid' => $uw?->aid,
            'best_pron_score' => $uw?->best_pron_score,
            'next_review' => $uw?->next_review?->toDateString(),
            'previews' => $uw ? $srs->previews($uw) : null,
        ];
    }

    private function card(Word $word, ?UserWord $uw, string $mode): array
    {
        return self::cardFor($word, $uw, $mode, $this->srs);
    }

    private function userWord(Request $request, Word $word, bool $mustBeIntroduced = false): UserWord
    {
        $uw = UserWord::firstOrNew(['user_id' => $request->user()->id, 'word_id' => $word->id]);
        abort_if($mustBeIntroduced && ! $uw->introduced_at, 422, 'Esta palabra todavía no está aprendida.');

        return $uw;
    }
}
