<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\ClaudeService;
use App\Services\PronunciationService;
use App\Services\SrsService;
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
        ]);
        $request->user()->update($data);

        return $request->user()->profile();
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

    public function learn(Request $request, Word $word)
    {
        $uw = $this->srs->learn($request->user(), $word);

        return $this->card($word, $uw, 'review');
    }

    public function review(Request $request, Word $word)
    {
        $data = $request->validate(['grade' => ['required', Rule::in(SrsService::GRADES)]]);
        $uw = $this->userWord($request, $word, mustBeIntroduced: true);
        $uw = $this->srs->review($request->user(), $uw, $data['grade']);

        return $this->card($word, $uw, 'review');
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
            $user->forceFill(['day_offset' => 0, 'streak' => 0, 'last_study_day' => null, 'cefr_level' => null])->save();
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
