<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ProgressService;
use Illuminate\Http\Request;

/** Panel de progreso del alumno. */
class ProgressController extends Controller
{
    public function __invoke(Request $request, ProgressService $progress)
    {
        return $progress->overview($request->user());
    }
}
