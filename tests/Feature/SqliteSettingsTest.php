<?php

namespace Tests\Feature;

use Illuminate\Database\Connectors\ConnectionFactory;
use PDO;
use Tests\TestCase;

/** SQLite espera en vez de fallar con "database is locked" cuando web y tareas escriben a la vez. */
class SqliteSettingsTest extends TestCase
{
    public function test_sqlite_espera_y_usa_wal(): void
    {
        $c = config('database.connections.sqlite');
        $this->assertGreaterThanOrEqual(3000, $c['busy_timeout']);
        $this->assertSame('wal', $c['journal_mode']);
        $this->assertSame('normal', $c['synchronous']);
        $this->assertSame('IMMEDIATE', $c['transaction_mode']);
    }

    /**
     * El choque del 17/11: un contador (lee y luego escribe en una transacción) y otra petición que escribe
     * en medio. Con IMMEDIATE la otra espera su turno y el contador termina bien (antes: "database is locked").
     */
    public function test_contador_no_falla_si_otra_peticion_escribe_a_la_vez(): void
    {
        $file = tempnam(sys_get_temp_dir(), 'w2w-lock-');
        try {
            $config = array_merge(config('database.connections.sqlite'), ['database' => $file, 'url' => null, 'name' => 'lock_test']);
            $db = app(ConnectionFactory::class)->make($config, 'lock_test');
            $db->statement('create table c (k text primary key, v integer)');
            $db->insert("insert into c values ('x', 0)");

            $other = new PDO('sqlite:'.$file);
            $other->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $other->exec('PRAGMA busy_timeout = 100');

            $otherWroteInside = false;
            $db->transaction(function ($db) use ($other, &$otherWroteInside) {
                $v = (int) $db->selectOne("select v from c where k = 'x'")->v;
                try {
                    $other->exec("update c set v = v + 10 where k = 'x'");
                    $otherWroteInside = true;
                } catch (\PDOException) {
                    // Esperó su turno: es lo correcto.
                }
                $db->update("update c set v = ? where k = 'x'", [$v + 1]);
            });

            $this->assertFalse($otherWroteInside, 'Otra conexión no debe poder escribir en medio del contador');
            $this->assertSame(1, (int) $db->selectOne("select v from c where k = 'x'")->v);
            $db->disconnect();
        } finally {
            foreach (['', '-wal', '-shm'] as $s) {
                @unlink($file.$s);
            }
        }
    }
}
