<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\DemoService;

class DemoController extends Controller
{
    /** "Probar la demo": a sample student just for this visitor, deleted after 24 h. */
    public function store(DemoService $demo)
    {
        $user = $demo->create();

        // One line per visit (the Huerga Labs admin panel counts them).
        @file_put_contents(storage_path('logs/demo-visits.log'), now()->toIso8601String()."\n", FILE_APPEND | LOCK_EX);

        return response()->json([
            'token' => $user->createToken('demo', ['*'], now()->addHours(DemoService::LIFETIME_HOURS))->plainTextToken,
            'user' => $user->fresh()->profile(),
        ], 201);
    }
}
