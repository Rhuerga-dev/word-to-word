<?php

namespace App\Services;

use App\Models\SpeakingMistake;
use App\Models\SpeakingSession;
use App\Models\User;
use App\Models\UserWord;
use Illuminate\Support\Facades\DB;

/** Logros: se calculan de lo que el alumno hizo de verdad y se guardan al desbloquearse. */
class AchievementService
{
    /** code => [título, descripción, ícono] (el orden es el de la pantalla). */
    public const LIST = [
        'first_session' => ['Primer paso', 'Termina tu primera sesión de Hoy', 'flag'],
        'streak_7' => ['Una semana', '7 días seguidos practicando', 'fire'],
        'streak_30' => ['Un mes', '30 días seguidos practicando', 'fire'],
        'goal_7' => ['Constante', 'Cumple tu meta diaria 7 días', 'target'],
        'words_100' => ['100 palabras', 'Aprende 100 palabras', 'book'],
        'words_500' => ['500 palabras', 'Aprende 500 palabras', 'book'],
        'speak_10' => ['Rompiendo el hielo', 'Habla 10 minutos en total', 'mic'],
        'speak_60' => ['Una hora hablando', 'Habla 60 minutos en total', 'mic'],
        'talks_10' => ['Conversador', 'Termina 10 conversaciones', 'chat'],
        'no_pauses' => ['Sin frenos', 'Habla 45 segundos seguidos sin pausas largas', 'bolt'],
        'sound_mastered' => ['Buen oído', 'Domina tu primer sonido', 'ear'],
        'mistakes_25' => ['Aprendo de mis errores', 'Supera 25 errores', 'check'],
        'unit_1' => ['Primera unidad', 'Aprueba la prueba de una unidad', 'map'],
        'level_done' => ['Nivel completo', 'Completa todas las unidades de tu nivel', 'trophy'],
    ];

    public function __construct(private SrsService $srs, private UnitService $units) {}

    /** Desbloquea lo que ya se cumple. Devuelve los logros nuevos (para avisar). */
    public function check(User $user): array
    {
        $have = DB::table('achievements')->where('user_id', $user->id)->pluck('code')->flip();
        $met = $this->met($user);
        $new = [];
        foreach (self::LIST as $code => $meta) {
            if (! isset($have[$code]) && ($met[$code] ?? false)) {
                DB::table('achievements')->insertOrIgnore(['user_id' => $user->id, 'code' => $code, 'unlocked_at' => now()]);
                $new[] = $this->card($code, now()->toIso8601String());
            }
        }

        return $new;
    }

    /** @return array<string, bool> */
    private function met(User $user): array
    {
        $streak = $this->srs->stats($user)['streak'];
        $learned = UserWord::where('user_id', $user->id)->whereNotNull('introduced_at')->count();
        $speechMin = SpeakingSession::where('user_id', $user->id)->sum('speech_ms') / 60000;
        $goal = (int) ($user->xp_goal ?: 100);
        $path = $this->units->path($user);
        $units = collect($path['units']);

        return [
            'first_session' => DB::table('xp_days')->where('user_id', $user->id)->where('sessions', '>', 0)->exists(),
            'streak_7' => $streak >= 7,
            'streak_30' => $streak >= 30,
            'goal_7' => DB::table('xp_days')->where('user_id', $user->id)->where('xp', '>=', $goal)->count() >= 7,
            'words_100' => $learned >= 100,
            'words_500' => $learned >= 500,
            'speak_10' => $speechMin >= 10,
            'speak_60' => $speechMin >= 60,
            'talks_10' => SpeakingSession::where('user_id', $user->id)->whereNotIn('scenario', ['narrate', 'picture'])->where('turns', '>=', 3)->count() >= 10,
            'no_pauses' => SpeakingSession::where('user_id', $user->id)->where('speech_ms', '>=', 45000)->where('long_pauses', 0)->exists(),
            'sound_mastered' => DB::table('phoneme_errors')->where('user_id', $user->id)->whereNotNull('mastered_on')->exists(),
            'mistakes_25' => SpeakingMistake::where('user_id', $user->id)->whereNotNull('mastered_on')->count() >= 25,
            'unit_1' => DB::table('unit_progress')->where('user_id', $user->id)->whereNotNull('passed_at')->exists(),
            'level_done' => $units->isNotEmpty() && $units->every(fn ($u) => $u['state'] === 'done'),
        ];
    }

    public function card(string $code, ?string $at = null): array
    {
        [$title, $desc, $icon] = self::LIST[$code];

        return ['code' => $code, 'title' => $title, 'desc' => $desc, 'icon' => $icon, 'unlocked_at' => $at];
    }

    /** Todos los logros, con los desbloqueados marcados. Los que aún no se habían mostrado salen en "new". */
    public function all(User $user): array
    {
        $this->check($user);
        $rows = DB::table('achievements')->where('user_id', $user->id)->get()->keyBy('code');
        $new = $rows->where('seen', false)->keys()->all();
        if ($new) {
            DB::table('achievements')->where('user_id', $user->id)->whereIn('code', $new)->update(['seen' => true]);
        }

        return [
            'achievements' => collect(self::LIST)->keys()->map(fn ($c) => $this->card($c, isset($rows[$c]) ? (string) $rows[$c]->unlocked_at : null))->values(),
            'unlocked' => $rows->count(),
            'total' => count(self::LIST),
            'new' => collect($new)->map(fn ($c) => $this->card($c))->values(),
        ];
    }
}
