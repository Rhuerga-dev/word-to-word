<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Cómo entiende el alumno al ESCUCHAR (no al leer): aciertos y fallos en el ejercicio de Oído
 * y cuántas veces pide "repeat" o "slower" en manos libres. Por día, en listening_days.
 * Si la tabla aún no existe (migración sin aplicar), no guarda nada y no opina.
 */
class ListeningService
{
    public const FIELDS = ['ear_ok', 'ear_fail', 'repeats'];

    private static ?bool $available = null;

    public function __construct(private SrsService $srs) {}

    public static function available(): bool
    {
        return self::$available ??= Schema::hasTable('listening_days');
    }

    /** Para los tests (cada uno crea la base de datos de nuevo). */
    public static function forget(): void
    {
        self::$available = null;
    }

    public function record(User $user, string $field): void
    {
        if (! in_array($field, self::FIELDS, true) || ! self::available()) {
            return;
        }
        $day = $this->srs->today($user)->toDateString();
        DB::table('listening_days')->updateOrInsert(['user_id' => $user->id, 'day' => $day], ['updated_at' => now()]);
        DB::table('listening_days')->where('user_id', $user->id)->where('day', $day)->increment($field);
    }

    /** Últimos 7 días. @return array{answers: int, ok: int, pct: int|null, repeats: int} */
    public function week(User $user): array
    {
        if (! self::available()) {
            return ['answers' => 0, 'ok' => 0, 'pct' => null, 'repeats' => 0];
        }
        $from = $this->srs->today($user)->subDays(6)->toDateString();
        $row = DB::table('listening_days')->where('user_id', $user->id)->where('day', '>=', $from)
            ->selectRaw('coalesce(sum(ear_ok),0) as ok, coalesce(sum(ear_fail),0) as fail, coalesce(sum(repeats),0) as repeats')->first();
        $answers = (int) $row->ok + (int) $row->fail;

        return [
            'answers' => $answers,
            'ok' => (int) $row->ok,
            'pct' => $answers ? (int) round($row->ok / $answers * 100) : null,
            'repeats' => (int) $row->repeats,
        ];
    }

    /** good (entiende al oír) · struggling (le cuesta) · unknown (aún no hay datos suficientes). */
    public function verdict(User $user): string
    {
        $w = $this->week($user);
        $c = config('spanish.listening');
        if (($w['answers'] >= $c['down_min'] && $w['pct'] < $c['down_pct']) || $w['repeats'] >= $c['repeats_down']) {
            return 'struggling';
        }
        if ($w['answers'] >= $c['up_min'] && $w['pct'] >= $c['up_pct'] && $w['repeats'] <= $w['answers'] * $c['repeats_up_ratio']) {
            return 'good';
        }

        return 'unknown';
    }
}
