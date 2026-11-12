<?php

return [
    // Dónde se guardan las copias de la base de datos (db:backup). Mejor fuera del Mac o en una carpeta sincronizada.
    'path' => env('BACKUP_PATH', storage_path('app/backups')),
];
