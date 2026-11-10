<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SpeakingMistake;
use App\Models\SpeakingSession;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\PictureService;
use App\Services\SpeakingService;
use App\Services\SrsService;
use App\Services\XpService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * "Hoy": la sesión guiada de unos 10 minutos que decide qué toca (fichas, tu sonido débil, hablar y tus errores).
 * La usan la web y la app Flutter.
 */
class SessionController extends Controller
{
    /** Cuántas cosas de cada tipo entran en una sesión. */
    public const REVIEWS = 5;

    public const NEW_WORDS = 3;

    public const MISTAKES = 3;

    /** Ejercicio de hablar de cada día (se rota). */
    public const SPEAK_MODES = ['narrate', 'picture', 'shadowing'];

    public function __construct(private SrsService $srs, private XpService $xp, private SpeakingService $speaking) {}

    public function today(Request $request, PictureService $pictures)
    {
        $user = $request->user();
        $today = $this->srs->today($user);
        $q = $this->srs->queue($user);

        $reviews = $q['reviews']->take(self::REVIEWS)->map(fn (UserWord $uw) => StudyController::cardFor($uw->word, $uw, 'review', $this->srs));
        $new = $q['new']->take(self::NEW_WORDS)->map(fn (Word $w) => StudyController::cardFor($w, null, 'new', $this->srs));

        // Sonidos que toca practicar (el más débil primero); la app elige el primero que tenga ejercicios.
        $sounds = DB::table('phoneme_errors')->where('user_id', $user->id)->whereNull('mastered_on')
            ->where(fn ($w) => $w->whereNull('next_practice')->orWhereDate('next_practice', '<=', $today->toDateString()))
            ->orderByDesc('count')->limit(5)->get(['phoneme', 'tier', 'stage'])
            ->map(fn ($s) => ['phoneme' => $s->phoneme, 'tier' => $s->tier ?? 'g', 'stage' => (int) $s->stage])->values();

        $modes = array_values(array_filter(self::SPEAK_MODES, fn ($m) => $m !== 'picture' || $pictures->enabled()));
        $done = (int) DB::table('xp_days')->where('user_id', $user->id)->where('day', $today->toDateString())->value('sessions');
        $speak = $modes[((int) $today->format('z') + $done) % count($modes)];

        $mistakes = SpeakingMistake::where('user_id', $user->id)->whereNull('mastered_on')
            ->whereDate('next_review', '<=', $today->toDateString())->orderBy('next_review')->limit(self::MISTAKES)->get()
            ->map->toCard()->values();

        return [
            'today' => $today->toDateString(),
            'xp' => $this->xp->today($user),
            'streak' => $this->srs->stats($user)['streak'],
            'plan' => [
                'reviews' => $reviews->values(),
                'new' => $new->values(),
                'sounds' => $sounds,
                'speak' => $speak,
                'mistakes' => $mistakes,
            ],
            'minutes' => round(SpeakingSession::where('user_id', $user->id)->whereDate('day', $today->toDateString())->sum('speech_ms') / 60000, 1),
        ];
    }

    /** Sesión terminada: bono de puntos y lo que mejoró hoy. */
    public function complete(Request $request)
    {
        $user = $request->user();
        $today = $this->srs->today($user)->toDateString();
        $bonus = $this->xp->add($user, 'session');
        DB::table('xp_days')->where('user_id', $user->id)->where('day', $today)->increment('sessions');

        $learned = UserWord::where('user_id', $user->id)->whereDate('introduced_at', $today)->count();
        $reviewed = (int) DB::table('study_days')->where('user_id', $user->id)->whereDate('day', $today)->value('review_count');
        $mistakesOk = SpeakingMistake::where('user_id', $user->id)->whereDate('reviewed_on', $today)->where('stage', '>', 0)->count();
        $tierUps = DB::table('phoneme_errors')->where('user_id', $user->id)->whereDate('practiced_on', $today)->whereIn('tier', ['p', 'd'])->pluck('phoneme');

        return [
            'xp_gained' => $bonus,
            'xp' => $this->xp->today($user->fresh()),
            'streak' => $this->srs->stats($user->fresh())['streak'],
            'today' => [
                'learned' => $learned,
                'reviewed' => $reviewed,
                'mistakes_ok' => $mistakesOk,
                'sounds' => $tierUps->values(),
                'minutes' => round(SpeakingSession::where('user_id', $user->id)->whereDate('day', $today)->sum('speech_ms') / 60000, 1),
            ],
        ];
    }
}
