<?php

namespace Tests\Feature;

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
    }
}
