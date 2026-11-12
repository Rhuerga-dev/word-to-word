<?php

namespace Tests\Feature;

use Tests\TestCase;

class BackupTest extends TestCase
{
    public function test_backup_writes_a_readable_copy_and_keeps_only_the_newest(): void
    {
        // VACUUM no puede ir dentro de una transacción, así que nada de RefreshDatabase: base en memoria recién migrada.
        $this->artisan('migrate');

        $dir = sys_get_temp_dir().'/w2w-backup-test-'.uniqid();
        mkdir($dir);
        foreach (['2020-01-01_000000', '2020-01-02_000000', '2020-01-03_000000'] as $d) {
            touch("{$dir}/w2w-{$d}.sqlite.gz");
        }

        $this->artisan('db:backup', ['--path' => $dir, '--keep' => 2])->assertSuccessful();

        $files = glob("{$dir}/w2w-*.sqlite.gz");
        sort($files);
        $this->assertCount(2, $files);
        $this->assertFileDoesNotExist("{$dir}/w2w-2020-01-01_000000.sqlite.gz");

        $copy = "{$dir}/check.sqlite";
        file_put_contents($copy, gzdecode(file_get_contents(end($files))));
        $tables = (new \PDO("sqlite:{$copy}"))->query("select name from sqlite_master where type='table'")->fetchAll(\PDO::FETCH_COLUMN);
        $this->assertContains('users', $tables);
        $this->assertSame('0600', substr(sprintf('%o', fileperms(end($files))), -4));

        array_map('unlink', glob("{$dir}/*"));
        rmdir($dir);
    }
}
