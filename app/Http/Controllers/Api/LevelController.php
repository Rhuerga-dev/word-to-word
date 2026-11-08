<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\LevelService;
use Illuminate\Http\Request;

class LevelController extends Controller
{
    public function __construct(private LevelService $levels) {}

    /** El camino completo (A1..C1), el progreso en el nivel actual y el historial. */
    public function index(Request $request)
    {
        $user = $request->user();

        return [
            'current' => $user->cefr_level,
            'levels' => $this->levels->overview(),
            'progress' => $this->levels->progress($user),
            'history' => $this->levels->history($user),
        ];
    }

    public function placement()
    {
        $questions = $this->levels->placementQuestions();
        abort_if(count($questions) === 0, 422, 'Todavía no hay palabras cargadas para hacer la prueba.');

        return ['questions' => $questions];
    }

    public function gradePlacement(Request $request)
    {
        $data = $request->validate($this->answerRules());
        $result = $this->levels->gradePlacement($request->user(), $data['answers']);

        return $result + ['progress' => $this->levels->progress($request->user()->fresh())];
    }

    /** Empezar en un nivel sin hacer la prueba (o cambiarlo a mano). */
    public function choose(Request $request)
    {
        $data = $request->validate(['level' => ['required', 'in:'.implode(',', $this->levels->codes())]]);
        $request->user()->forceFill(['cefr_level' => $data['level']])->save();

        return ['progress' => $this->levels->progress($request->user()->fresh())];
    }

    public function exam(Request $request)
    {
        $user = $request->user();
        abort_unless($user->cefr_level, 422, 'Primero haz la prueba de nivel.');
        $progress = $this->levels->progress($user);
        abort_unless($progress['exam_ready'], 422,
            'Aprende al menos '.$progress['exam_needed'].' palabras de tu nivel para presentar el examen.');

        return ['level' => $user->cefr_level, 'questions' => $this->levels->examQuestions($user)];
    }

    public function gradeExam(Request $request)
    {
        $user = $request->user();
        abort_unless($user->cefr_level, 422, 'Primero haz la prueba de nivel.');
        abort_unless($this->levels->progress($user)['exam_ready'], 422, 'Todavía no puedes presentar el examen.');
        $data = $request->validate($this->answerRules());
        $result = $this->levels->gradeExam($user, $data['answers']);

        return $result + ['progress' => $this->levels->progress($user->fresh())];
    }

    private function answerRules(): array
    {
        return [
            'answers' => ['required', 'array', 'min:1', 'max:60'],
            'answers.*.word_id' => ['required', 'integer', 'distinct'],
            'answers.*.answer' => ['present', 'nullable', 'string', 'max:255'],
        ];
    }
}
