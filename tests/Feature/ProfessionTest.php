<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\SpeakingService;
use App\Support\Professions;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Profesión del alumno: qué conversaciones, unidades y temas ve. Sin profesión, todo como siempre. */
class ProfessionTest extends TestCase
{
    use RefreshDatabase;

    private function scenarioIds(): array
    {
        return array_column($this->getJson('/api/speaking/scenarios')->assertOk()->json('scenarios'), 'id');
    }

    public function test_without_profession_everything_stays_as_before(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $this->getJson('/api/me')->assertJsonPath('profession', null)->assertJsonPath('goal', null);
        $ids = $this->scenarioIds();
        $this->assertContains('upwork_call', $ids);
        $this->assertContains('standup', $ids);
        $this->assertNotContains('job_interview_any', $ids);   // las plantillas solo con profesión
        $this->assertSame('upwork_call', Professions::scenarioFor(null, 'upwork_call'));
    }

    public function test_choosing_a_profession_swaps_developer_content_for_templates(): void
    {
        Sanctum::actingAs($user = User::factory()->create(['freelance_pack' => true]));

        $this->putJson('/api/profile', ['profession' => 'health', 'goal' => 'work'])->assertOk()
            ->assertJsonPath('profession', 'health')->assertJsonPath('goal', 'work')
            ->assertJsonPath('freelance_pack', false);   // el mazo freelance es de developers

        $ids = $this->scenarioIds();
        foreach (['upwork_call', 'present_project', 'job_interview', 'standup'] as $dev) {
            $this->assertNotContains($dev, $ids);
        }
        foreach (['job_interview_any', 'work_boss', 'work_customer', 'explain_job', 'doctor', 'free'] as $id) {
            $this->assertContains($id, $ids);
        }
    }

    public function test_tech_keeps_the_developer_content(): void
    {
        Sanctum::actingAs(User::factory()->create(['freelance_pack' => false]));

        $this->putJson('/api/profile', ['profession' => 'tech'])->assertOk()->assertJsonPath('freelance_pack', true);
        $ids = $this->scenarioIds();
        $this->assertContains('upwork_call', $ids);
        $this->assertNotContains('job_interview_any', $ids);
    }

    public function test_invalid_profession_or_goal_is_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/profile', ['profession' => 'astronaut'])->assertStatus(422);
        $this->putJson('/api/profile', ['goal' => 'fame'])->assertStatus(422);
        $this->getJson('/api/professions')->assertOk()->assertJsonPath('professions.0.id', 'tech')->assertJsonCount(5, 'goals');
    }

    public function test_students_and_home_get_no_boss_or_customer_conversations(): void
    {
        $this->assertSame('free', Professions::scenarioFor('student', 'standup'));
        $this->assertSame('explain_job', Professions::scenarioFor('home', 'present_project'));
        $this->assertSame('work_customer', Professions::scenarioFor('restaurant', 'upwork_call'));
        $this->assertSame('doctor', Professions::scenarioFor('restaurant', 'doctor'));
    }

    public function test_the_ai_role_gets_the_students_job(): void
    {
        $role = Professions::role(config('speaking.scenarios.job_interview_any.role'), 'delivery');
        $this->assertStringContainsString('delivery driver position', $role);
        $this->assertStringNotContainsString('{job}', $role);
        $this->assertStringNotContainsString('{who}', Professions::role(config('speaking.scenarios.work_boss.role'), null));
    }

    public function test_path_units_adapt_to_the_profession(): void
    {
        config(['units.levels' => ['B1' => [
            ['id' => 'b1-freelance', 'title' => 'Trabajo freelance', 'source' => 'freelance', 'words' => ['client'], 'sound' => 'θ', 'scenario' => 'upwork_call', 'shadow' => 'x',
                'alt' => ['title' => 'Clientes y trabajo', 'words' => ['customer']]],
            ['id' => 'b1-health', 'title' => 'Salud', 'words' => ['doctor'], 'sound' => 'i', 'scenario' => 'doctor', 'shadow' => 'x'],
        ]]]);
        $user = User::factory()->create(['cefr_level' => 'B1']);
        Sanctum::actingAs($user);

        $this->getJson('/api/path')->assertOk()
            ->assertJsonPath('units.0.title', 'Trabajo freelance')->assertJsonPath('units.0.scenario', 'upwork_call');

        $user->update(['profession' => 'restaurant']);
        $this->getJson('/api/path')->assertOk()
            ->assertJsonPath('units.0.title', 'Clientes y trabajo')
            ->assertJsonPath('units.0.scenario', 'work_customer')
            ->assertJsonPath('units.0.scenario_title', 'Atender a un cliente')
            ->assertJsonPath('units.1.scenario', 'doctor');
    }

    public function test_narration_never_gives_developer_topics_to_other_professions(): void
    {
        $user = User::factory()->create(['profession' => 'cleaning']);
        $speaking = app(SpeakingService::class);
        $tech = collect(config('speaking.narration_topics'))->filter(fn ($t) => ($t[2] ?? null) === 'tech')->pluck(0)->all();
        $this->assertNotEmpty($tech);
        for ($skip = 0; $skip < 40; $skip++) {
            $this->assertNotContains($speaking->topic($user, $skip)['en'], $tech);
        }
    }
}
