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
        ];
    }

    /** La sesión de hoy: primero repasos, luego palabras nuevas. */
    public function today(Request $request)
    {
        $user = $request->user();
        $q = $this->srs->queue($user);

        $cards = $q['reviews']->map(fn (UserWord $uw) => $this->card($uw->word, $uw, 'review'))
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
        $data = $request->validate(['daily_new' => ['required', 'integer', 'min:1', 'max:50']]);
        $request->user()->update($data);

        return ['daily_new' => $request->user()->daily_new];
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
            $user->forceFill(['day_offset' => 0, 'streak' => 0, 'last_study_day' => null])->save();
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
