<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserWord;
use App\Models\Word;
use App\Services\EarService;
use App\Services\SpanishService;
use App\Services\XpService;
use Illuminate\Http\Request;

/** Oído: reconocer de oído las palabras que ya aprendiste. */
class EarController extends Controller
{
    public function __construct(private EarService $ear) {}

    /** GET /ear: palabras para practicar por oído fuera de la sesión. */
    public function index(Request $request)
    {
        $user = $request->user();
        $limit = (int) ($request->validate(['limit' => ['sometimes', 'integer', 'min:1', 'max:20']])['limit'] ?? 10);

        return [
            'items' => $this->ear->due($user, $limit, app(SpanishService::class)->step($user)),
            'automatic' => $this->ear->automaticCount($user),
        ];
    }

    /** POST /words/{word}/ear: si la reconociste y cuánto tardaste desde que terminó de sonar. */
    public function answer(Request $request, Word $word, XpService $xp)
    {
        $data = $request->validate(['ok' => ['required', 'boolean'], 'ms' => ['required', 'integer', 'min:0', 'max:600000']]);
        $user = $request->user();
        $uw = UserWord::where('user_id', $user->id)->where('word_id', $word->id)->whereNotNull('introduced_at')->first();
        abort_unless($uw, 404, 'Esa palabra todavía no está en tus fichas.');

        $out = $this->ear->answer($user, $uw, $data['ok'], $data['ms']);

        return $out + ['xp_gained' => $out['fast'] ? $xp->add($user, 'ear') : 0, 'automatic_total' => $this->ear->automaticCount($user)];
    }
}
