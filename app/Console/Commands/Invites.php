<?php

namespace App\Console\Commands;

use App\Models\InvitationCode;
use App\Services\InviteService;
use Illuminate\Console\Command;
use InvalidArgumentException;

/**
 * Códigos de invitación (los usa el panel de Huerga Labs con una lista fija de comandos):
 *   invites list
 *   invites create --uses=10 [--days=30] [--note="Familia"] [--code=FAMILIA]
 *   invites disable CODIGO
 * Siempre responde en JSON.
 */
class Invites extends Command
{
    protected $signature = 'invites {action : list | create | disable} {code? : el código (para disable)}
        {--uses=1 : cuántas personas pueden usarlo} {--days= : caduca en N días} {--note= : para qué es} {--code= : código propio (si no, uno al azar)}';

    protected $description = 'Crea, lista y desactiva códigos de invitación (salida JSON para el panel)';

    public function handle(InviteService $invites): int
    {
        if (! InviteService::available()) {
            return $this->out(['ok' => false, 'error' => 'Falta aplicar la migración de invitaciones.'], self::FAILURE);
        }
        try {
            return match ($this->argument('action')) {
                'list' => $this->out(['ok' => true, 'codes' => InvitationCode::latest('id')->limit(200)->get()->map->toPanel()->all()]),
                'create' => $this->out(['ok' => true, 'code' => $invites->create(
                    (int) $this->option('uses'),
                    $this->option('days') !== null ? (int) $this->option('days') : null,
                    $this->option('note'),
                    $this->option('code'),
                )->toPanel()]),
                'disable' => ($inv = $invites->disable((string) $this->argument('code')))
                    ? $this->out(['ok' => true, 'code' => $inv->toPanel()])
                    : $this->out(['ok' => false, 'error' => 'Ese código no existe.'], self::FAILURE),
                default => $this->out(['ok' => false, 'error' => 'Acción desconocida.'], self::INVALID),
            };
        } catch (InvalidArgumentException $e) {
            return $this->out(['ok' => false, 'error' => $e->getMessage()], self::FAILURE);
        }
    }

    private function out(array $data, int $code = self::SUCCESS): int
    {
        $this->line(json_encode($data, JSON_UNESCAPED_UNICODE));

        return $code;
    }
}
