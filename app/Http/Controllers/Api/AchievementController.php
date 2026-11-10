<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AchievementService;
use App\Services\LeagueService;
use Illuminate\Http\Request;

/** Logros y liga semanal. */
class AchievementController extends Controller
{
    public function index(Request $request, AchievementService $achievements)
    {
        return $achievements->all($request->user());
    }

    public function league(Request $request, LeagueService $league)
    {
        return $league->week($request->user());
    }

    public function visibility(Request $request, LeagueService $league)
    {
        $data = $request->validate(['visible' => ['required', 'boolean']]);
        $request->user()->forceFill(['league_visible' => $data['visible']])->save();

        return $league->week($request->user());
    }
}
