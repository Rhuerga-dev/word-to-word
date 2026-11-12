<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\AiUsage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AiCostsTest extends TestCase
{
    use RefreshDatabase;

    public function test_records_the_cost_of_each_call_with_its_student(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        AiUsage::claude('converse', ['input_tokens' => 2000, 'output_tokens' => 200]);   // 0.0002 + 0.0001
        AiUsage::speech('transcribe', str_repeat("\0", 44 + 32 * 3600));                   // 3,6 s a 1 USD/h = 0.001
        AiUsage::speech('assess', str_repeat("\0", 44 + 32 * 3600));                       // 3,6 s a 1,30 USD/h = 0.0013
        AiUsage::tts(str_repeat('a', 1000));                                               // 1000 car. a 15 USD/M = 0.015

        $rows = DB::table('ai_usage')->where('user_id', $user->id)->orderBy('id')->get();
        $this->assertSame(['converse', 'transcribe', 'assess', 'tts'], $rows->pluck('kind')->all());
        $this->assertEqualsWithDelta(0.0003, (float) $rows[0]->cost_usd, 1e-6);
        $this->assertSame(3600, (int) $rows[1]->audio_ms);
        $this->assertEqualsWithDelta(0.001, (float) $rows[1]->cost_usd, 1e-6);
        $this->assertEqualsWithDelta(0.0013, (float) $rows[2]->cost_usd, 1e-6);
        $this->assertEqualsWithDelta(0.015, (float) $rows[3]->cost_usd, 1e-6);
    }

    public function test_command_reports_cost_per_student_day(): void
    {
        $a = User::factory()->create(['email' => 'ana@example.com']);
        $b = User::factory()->create(['email' => 'beto@example.com']);
        $row = fn ($u, $day, $c) => ['user_id' => $u, 'day' => $day, 'provider' => 'azure', 'kind' => 'transcribe', 'cost_usd' => $c, 'created_at' => now()];
        DB::table('ai_usage')->insert([
            $row($a->id, now()->toDateString(), 0.04),
            $row($a->id, now()->subDay()->toDateString(), 0.06),
            $row($b->id, now()->toDateString(), 0.08),
            $row(null, now()->toDateString(), 0.50),
        ]);

        $this->artisan('ai:costs', ['--days' => 7])
            ->expectsOutputToContain('0.6800 USD en total')
            ->expectsOutputToContain('Alumnos: 2 con actividad, 3 días-alumno. Por día de estudio: media 0.0600 USD')
            ->expectsOutputToContain('unos 1.20 USD por alumno')
            ->assertSuccessful();
    }
}
