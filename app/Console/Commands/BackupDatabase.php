<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Copia de seguridad de la base sqlite: una foto consistente con VACUUM INTO (segura aunque la app
 * esté escribiendo), comprimida con gzip, y se quedan solo las N más recientes.
 * La carpeta sale de BACKUP_PATH; si apunta a otro disco o a una carpeta sincronizada, la copia
 * sobrevive aunque el Mac se pierda.
 */
class BackupDatabase extends Command
{
    protected $signature = 'db:backup {--keep=14} {--path=}';

    protected $description = 'Guarda una copia comprimida de la base de datos y borra las viejas';

    public function handle(): int
    {
        if (DB::connection()->getDriverName() !== 'sqlite') {
            $this->error('Solo sé hacer copias de sqlite.');

            return self::FAILURE;
        }

        $dir = rtrim($this->option('path') ?: config('backup.path'), '/');
        if (! is_dir($dir) && ! @mkdir($dir, 0700, true)) {
            $this->error("No puedo crear la carpeta {$dir}.");

            return self::FAILURE;
        }

        $name = 'w2w-'.now()->format('Y-m-d_His');
        $raw = "{$dir}/{$name}.sqlite";
        DB::statement('VACUUM INTO ?', [$raw]);

        $gz = gzopen("{$raw}.gz", 'wb6');
        $in = fopen($raw, 'rb');
        while (! feof($in)) {
            gzwrite($gz, fread($in, 1 << 20));
        }
        fclose($in);
        gzclose($gz);
        unlink($raw);
        chmod("{$raw}.gz", 0600);

        $all = glob("{$dir}/w2w-*.sqlite.gz") ?: [];
        sort($all);
        $old = array_slice($all, 0, max(0, count($all) - max(1, (int) $this->option('keep'))));
        array_map('unlink', $old);

        $this->info("Copia guardada: {$raw}.gz (".round(filesize("{$raw}.gz") / 1024).' KB). Borradas: '.count($old).'.');

        return self::SUCCESS;
    }
}
