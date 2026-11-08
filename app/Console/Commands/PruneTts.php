<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

/**
 * Limpia la caché de audios de voz (storage/app/tts): borra los que llevan más de N días sin usarse
 * y, si aun así la carpeta pasa del tope, los más viejos primero. Así nadie puede llenar el disco.
 */
class PruneTts extends Command
{
    protected $signature = 'tts:prune {--days=60} {--max-mb=500}';

    protected $description = 'Borra audios de voz viejos y mantiene la caché por debajo del tope';

    public function handle(): int
    {
        $disk = Storage::disk('local');
        $cutoff = now()->subDays((int) $this->option('days'))->getTimestamp();
        $max = (int) $this->option('max-mb') * 1024 * 1024;

        $files = collect($disk->files('tts'))
            ->filter(fn ($f) => str_ends_with($f, '.mp3'))
            ->map(fn ($f) => ['path' => $f, 'time' => $disk->lastModified($f), 'size' => $disk->size($f)])
            ->sortBy('time')->values();

        $deleted = 0;
        $total = $files->sum('size');
        foreach ($files as $f) {
            if ($f['time'] >= $cutoff && $total <= $max) {
                break;
            }
            $disk->delete($f['path']);
            $total -= $f['size'];
            $deleted++;
        }

        $this->info("Audios borrados: {$deleted}. Tamaño ahora: ".round($total / 1048576, 1).' MB.');

        return self::SUCCESS;
    }
}
