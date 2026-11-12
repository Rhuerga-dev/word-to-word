<?php

namespace App\Console\Commands;

use App\Services\PronunciationService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Process;
use Throwable;

/**
 * Compara Whisper (local, whisper.cpp) con Azure al pasar voz a texto: lo que entiende cada uno, cuánto
 * se equivoca (WER) y cuánto tarda. Lee los WAV de una carpeta (16 kHz mono) y, si existe, expected.txt
 * con la frase correcta de cada uno ("1.wav|I think so.").
 */
class SpeechCompare extends Command
{
    protected $signature = 'speech:compare {dir} {--models=ggml-small.en.bin,ggml-large-v3-turbo-q5_0.bin} {--no-azure} {--server= : URL de whisper-server (modelo ya cargado en memoria)}';

    protected $description = 'Compara Whisper local con Azure en unas grabaciones';

    public function handle(PronunciationService $azure): int
    {
        $dir = rtrim($this->argument('dir'), '/');
        $files = glob($dir.'/*.wav') ?: [];
        natsort($files);
        if (! $files) {
            $this->error("No hay archivos .wav en {$dir}.");

            return self::FAILURE;
        }
        $expected = [];
        // La frase de cada grabación: expected.txt junto a la carpeta, o las 8 frases de prueba de la app (1.m4a … 8.m4a).
        $exp = is_file($dir.'/../expected.txt') ? $dir.'/../expected.txt' : resource_path('speech/expected.txt');
        foreach (@file($exp, FILE_IGNORE_NEW_LINES) ?: [] as $line) {
            if (str_contains($line, '|')) {
                [$f, $t] = explode('|', $line, 2);
                $expected[pathinfo(trim($f), PATHINFO_FILENAME)] = trim($t);
            }
        }

        $cli = collect([env('WHISPER_CLI'), '/opt/homebrew/bin/whisper-cli', '/usr/local/bin/whisper-cli'])->first(fn ($p) => $p && is_executable($p));
        $models = collect(explode(',', $this->option('models')))
            ->map(fn ($m) => (getenv('HOME') ?: '/tmp').'/Code/whisper-models/'.trim($m))->filter(fn ($p) => is_file($p))->values();
        if (! $cli) {
            $this->warn('No encontré whisper-cli: solo Azure.');
        }

        $engines = [];
        if ($cli) {
            foreach ($models as $m) {
                $engines[basename($m, '.bin')] = fn (string $wav) => $this->whisper($cli, $m, $wav);
            }
        }
        if ($url = $this->option('server')) {
            $engines['whisper-server'] = fn (string $wav) => (string) \Illuminate\Support\Facades\Http::timeout(60)
                ->attach('file', file_get_contents($wav), basename($wav))
                ->post(rtrim($url, '/').'/inference', ['response_format' => 'json', 'language' => 'en', 'temperature' => '0'])
                ->throw()->json('text');
        }
        if (! $this->option('no-azure') && $azure->enabled()) {
            $engines['azure'] = fn (string $wav) => $azure->azureTranscribe(file_get_contents($wav))['text'] ?? '';
        }

        $totals = [];
        foreach ($files as $wav) {
            $name = pathinfo($wav, PATHINFO_FILENAME);
            $secs = max(0, (filesize($wav) - 44) / 32000);
            $want = $expected[$name] ?? null;
            $this->line(sprintf("\n%s (%.1f s)%s", basename($wav), $secs, $want ? " · esperado: {$want}" : ''));
            foreach ($engines as $label => $run) {
                $t0 = microtime(true);
                try {
                    $text = trim($run($wav));
                } catch (Throwable $e) {
                    $text = '(error: '.$e->getMessage().')';
                }
                $ms = (int) round((microtime(true) - $t0) * 1000);
                $wer = $want !== null ? self::wer($want, $text) : null;
                $totals[$label]['ms'][] = $ms;
                if ($wer !== null) {
                    $totals[$label]['wer'][] = $wer;
                }
                $this->line(sprintf('  %-28s %5d ms%s  %s', $label, $ms, $wer !== null ? sprintf('  WER %3d%%', round($wer * 100)) : '', $text));
            }
        }

        $this->line("\nResumen (WER = % de palabras mal; menos es mejor):");
        foreach ($totals as $label => $t) {
            $this->line(sprintf('  %-28s media %5d ms%s', $label, array_sum($t['ms']) / count($t['ms']),
                isset($t['wer']) ? sprintf('  ·  WER medio %d%%', round(array_sum($t['wer']) / count($t['wer']) * 100)) : ''));
        }

        return self::SUCCESS;
    }

    private function whisper(string $cli, string $model, string $wav): string
    {
        $r = Process::timeout(120)->run([$cli, '-m', $model, '-f', $wav, '-l', 'en', '-nt', '-np', '-t', '4']);
        if (! $r->successful()) {
            throw new \RuntimeException(trim($r->errorOutput()) ?: 'whisper-cli falló');
        }

        return preg_replace('/\s+/', ' ', $r->output());
    }

    /** Word error rate: ediciones de palabras / palabras esperadas (sin mayúsculas ni signos). */
    public static function wer(string $want, string $got): float
    {
        $norm = fn ($s) => array_values(array_filter(explode(' ', preg_replace('/[^a-z0-9\' ]/', ' ', strtolower(str_replace('’', "'", $s))))));
        $a = $norm($want);
        $b = $norm($got);
        if (! $a) {
            return $b ? 1.0 : 0.0;
        }
        $prev = range(0, count($b));
        foreach ($a as $i => $wa) {
            $cur = [$i + 1];
            foreach ($b as $j => $wb) {
                $cur[] = min($prev[$j + 1] + 1, $cur[$j] + 1, $prev[$j] + ($wa === $wb ? 0 : 1));
            }
            $prev = $cur;
        }

        return min(1.0, end($prev) / count($a));
    }
}
