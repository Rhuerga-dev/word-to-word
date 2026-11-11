<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserWord;
use App\Models\Word;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Borrar la cuenta (Google Play lo exige): desde la app y desde la web, con todo lo que tiene. */
class AccountDeletionTest extends TestCase
{
    use RefreshDatabase;

    private function userWithData(): User
    {
        $u = User::factory()->create(['email' => 'ana@example.com', 'password' => 'secreta123']);
        $w = Word::create(['word' => 'rent', 'rank' => 5, 'translation' => 'alquiler']);
        UserWord::create(['user_id' => $u->id, 'word_id' => $w->id, 'introduced_at' => today()]);
        DB::table('xp_days')->insert(['user_id' => $u->id, 'day' => today()->toDateString(), 'xp' => 10, 'created_at' => now(), 'updated_at' => now()]);

        return $u;
    }

    public function test_desde_la_app_con_la_contrasena(): void
    {
        $u = $this->userWithData();
        $token = $u->createToken('app')->plainTextToken;
        $h = ['Authorization' => "Bearer {$token}"];

        $this->deleteJson('/api/account', ['password' => 'otra'], $h)->assertStatus(422);
        $this->assertNotNull(User::find($u->id));

        $this->deleteJson('/api/account', ['password' => 'secreta123'], $h)->assertNoContent();
        $this->assertNull(User::find($u->id));
        $this->assertSame(0, UserWord::where('user_id', $u->id)->count());
        $this->assertSame(0, DB::table('xp_days')->where('user_id', $u->id)->count());
        $this->assertSame(0, DB::table('personal_access_tokens')->count());
    }

    public function test_desde_la_web_con_correo_y_contrasena(): void
    {
        $u = $this->userWithData();
        $this->postJson('/api/account/delete', ['email' => 'ana@example.com', 'password' => 'mal'])->assertStatus(422);
        $this->postJson('/api/account/delete', ['email' => 'nadie@example.com', 'password' => 'secreta123'])->assertStatus(422);
        $this->assertNotNull(User::find($u->id));

        $this->postJson('/api/account/delete', ['email' => 'ana@example.com', 'password' => 'secreta123'])->assertOk()->assertJsonPath('deleted', true);
        $this->assertNull(User::find($u->id));
        $this->assertSame(0, UserWord::count());
    }

    public function test_sin_sesion_no_se_puede_borrar_desde_la_app(): void
    {
        $this->deleteJson('/api/account', ['password' => 'x'])->assertUnauthorized();
    }

    public function test_la_pagina_publica_y_la_politica_existen(): void
    {
        $this->assertFileExists(public_path('cuenta/borrar/index.html'));
        $this->assertFileExists(public_path('privacidad/index.html'));
    }
}
