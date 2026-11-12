<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Apunta lo que cuesta cada llamada a Claude o a Azure Speech, con su alumno, para medir el coste por alumno
 * (php artisan ai:costs). Las tarifas están en config/vocab.php → prices. Nunca rompe la petición si falla.
 */
class AiUsage
{
    public static function claude(string $kind, ?array $usage): void
    {
        $in = (int) ($usage['input_tokens'] ?? 0) + (int) ($usage['cache_creation_input_tokens'] ?? 0);
        $cached = (int) ($usage['cache_read_input_tokens'] ?? 0);
        $out = (int) ($usage['output_tokens'] ?? 0);
        $p = config('vocab.prices');
        $cost = ($in * $p['claude_input'] + $cached * $p['claude_cached'] + $out * $p['claude_output']) / 1_000_000;
        self::put('claude', $kind, ['input_tokens' => $in + $cached, 'output_tokens' => $out], $cost);
    }

    /** Audio enviado a Azure (WAV 16 kHz mono 16 bits = 32 bytes por ms). [kind]: transcribe | assess. */
    public static function speech(string $kind, string $wav): void
    {
        $ms = (int) max(0, (strlen($wav) - 44) / 32);
        $perHour = config('vocab.prices.'.($kind === 'assess' ? 'azure_assess_hour' : 'azure_stt_hour'));
        self::put('azure', $kind, ['audio_ms' => $ms], $ms / 3_600_000 * $perHour);
    }

    public static function tts(string $text): void
    {
        $chars = mb_strlen($text);
        self::put('azure', 'tts', ['chars' => $chars], $chars * config('vocab.prices.azure_tts_million_chars') / 1_000_000);
    }

    private static function put(string $provider, string $kind, array $units, float $cost): void
    {
        try {
            $user = auth('sanctum')->id() ?? auth()->id();
            DB::table('ai_usage')->insert($units + [
                'user_id' => $user,
                'day' => now()->toDateString(),
                'provider' => $provider,
                'kind' => substr($kind, 0, 32),
                'cost_usd' => round($cost, 6),
                'created_at' => now(),
            ]);
        } catch (Throwable $e) {
            report($e);
        }
    }
}
