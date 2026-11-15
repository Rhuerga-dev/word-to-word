<?php

namespace App\Services;

use App\Models\InvitationCode;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use InvalidArgumentException;

/**
 * Códigos de invitación para registrarse. Los crea Reynaldo desde el panel (comandos invites:*).
 * Un código sirve para varias personas hasta max_uses, puede caducar y se puede desactivar.
 */
class InviteService
{
    /** Sin letras que se confunden (0/O, 1/I/L). */
    private const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    public static function available(): bool
    {
        return Schema::hasTable('invitation_codes');
    }

    public static function normalize(string $code): string
    {
        return strtoupper(trim(preg_replace('/\s+/', '', $code)));
    }

    public function create(int $uses, ?int $days = null, ?string $note = null, ?string $code = null): InvitationCode
    {
        if ($uses < 1 || $uses > 1000) {
            throw new InvalidArgumentException('Los usos van de 1 a 1000.');
        }
        if ($days !== null && ($days < 1 || $days > 365)) {
            throw new InvalidArgumentException('La caducidad va de 1 a 365 días.');
        }
        if ($code !== null) {
            $code = self::normalize($code);
            if (! preg_match('/^[A-Z0-9-]{4,24}$/', $code)) {
                throw new InvalidArgumentException('El código: de 4 a 24 letras, números o guiones.');
            }
            if (InvitationCode::where('code', $code)->exists()) {
                throw new InvalidArgumentException('Ese código ya existe.');
            }
        } else {
            do {
                $code = 'W2W-'.$this->random(4).'-'.$this->random(4);
            } while (InvitationCode::where('code', $code)->exists());
        }

        return InvitationCode::create([
            'code' => $code,
            'max_uses' => $uses,
            'expires_at' => $days ? now()->addDays($days) : null,
            'note' => $note !== null ? Str::limit(trim($note), 117) : null,
        ]);
    }

    /**
     * Gasta un uso del código, de forma atómica (dos personas a la vez no pueden pasarse del límite).
     * Devuelve el id del código o null si no vale (no existe, agotado, caducado o desactivado).
     */
    public function redeem(string $code): ?int
    {
        $code = self::normalize($code);
        $row = InvitationCode::where('code', $code)->first(['id']);
        if (! $row) {
            return null;
        }
        $ok = DB::table('invitation_codes')
            ->where('id', $row->id)
            ->where('active', true)
            ->whereColumn('used', '<', 'max_uses')
            ->where(fn ($q) => $q->whereNull('expires_at')->orWhere('expires_at', '>', now()))
            ->increment('used');

        return $ok === 1 ? $row->id : null;
    }

    public function disable(string $code): ?InvitationCode
    {
        $inv = InvitationCode::where('code', self::normalize($code))->first();
        $inv?->update(['active' => false]);

        return $inv;
    }

    private function random(int $n): string
    {
        $out = '';
        for ($i = 0; $i < $n; $i++) {
            $out .= self::ALPHABET[random_int(0, strlen(self::ALPHABET) - 1)];
        }

        return $out;
    }
}
