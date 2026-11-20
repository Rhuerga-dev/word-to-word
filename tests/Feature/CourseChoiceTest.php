<?php

namespace Tests\Feature;

use App\Models\Course;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Elegir curso: el alumno ve los cursos abiertos y puede cambiar; los apagados, solo las cuentas de prueba. */
class CourseChoiceTest extends TestCase
{
    use RefreshDatabase;

    private Course $spanish;

    protected function setUp(): void
    {
        parent::setUp();
        $this->spanish = Course::create(['code' => 'es-en', 'learn' => 'es', 'from' => 'en', 'name' => 'Spanish for English speakers', 'speech_locale' => 'es-US', 'active' => false]);
        config(['vocab.course_testers' => []]);
    }

    public function test_a_student_sees_only_the_open_courses_and_which_one_is_theirs(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $r = $this->getJson('/api/courses')->assertOk();
        $this->assertSame('en-es', $r->json('current'));
        $this->assertSame(['en-es'], collect($r->json('courses'))->pluck('code')->all());
        $this->assertSame(['code' => 'en-es', 'name' => 'Inglés para hispanohablantes', 'learn' => 'en', 'from' => 'es'], $this->getJson('/api/me')->json('course'));
    }

    public function test_a_course_that_is_switched_off_cannot_be_chosen(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->putJson('/api/course', ['code' => 'es-en'])->assertStatus(422);
        $this->putJson('/api/course', ['code' => 'no-existe'])->assertStatus(422);
        $this->assertSame(Course::DEFAULT_ID, (int) $user->fresh()->course_id);
    }

    public function test_once_open_anyone_can_choose_it_and_go_back(): void
    {
        $this->spanish->update(['active' => true]);
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $r = $this->putJson('/api/course', ['code' => 'es-en'])->assertOk();
        $this->assertSame('es-en', $r->json('current'));
        $this->assertSame('es', $r->json('profile.course.learn'));
        $this->assertSame($this->spanish->id, (int) $user->fresh()->course_id);

        $this->putJson('/api/course', ['code' => 'en-es'])->assertOk()->assertJsonPath('current', 'en-es');
    }

    public function test_test_accounts_from_the_fixed_list_see_courses_under_construction(): void
    {
        $tester = User::factory()->create();
        config(['vocab.course_testers' => [$tester->id]]);
        Sanctum::actingAs($tester);

        $courses = collect($this->getJson('/api/courses')->assertOk()->json('courses'));
        $this->assertSame(['en-es', 'es-en'], $courses->pluck('code')->all());
        $this->assertFalse($courses->firstWhere('code', 'es-en')['active']);
        $this->putJson('/api/course', ['code' => 'es-en'])->assertOk();
    }

    public function test_the_sign_up_form_can_offer_the_open_courses(): void
    {
        $this->assertSame(['en-es'], collect($this->getJson('/api/config')->assertOk()->json('courses'))->pluck('code')->all());

        $this->spanish->update(['active' => true]);
        $courses = $this->getJson('/api/config')->json('courses');
        $this->assertSame(['en-es', 'es-en'], array_column($courses, 'code'));
        $this->assertSame(['code' => 'es-en', 'name' => 'Spanish for English speakers', 'learn' => 'es', 'from' => 'en'], $courses[1]);
    }

    public function test_a_new_student_can_choose_the_course_when_signing_up(): void
    {
        config(['vocab.invites_required' => false]);
        \Illuminate\Support\Facades\Notification::fake();
        $form = fn (string $email, array $more = []) => $this->postJson('/api/auth/register', ['name' => 'Ann', 'email' => $email, 'password' => 'una-clave-larga-123'] + $more);

        // Apagado: no se puede elegir (ni inventar un código).
        $form('a@example.org', ['course' => 'es-en'])->assertStatus(422)->assertJsonValidationErrors('course');
        $form('a@example.org', ['course' => 'xx'])->assertStatus(422);

        $this->spanish->update(['active' => true]);
        $form('ann@example.org', ['course' => 'es-en'])->assertSuccessful();
        $this->assertSame($this->spanish->id, (int) User::where('email', 'ann@example.org')->value('course_id'));

        // Sin decir nada (una app antigua): el curso de siempre.
        $form('bob@example.org')->assertSuccessful();
        $this->assertSame(Course::DEFAULT_ID, (int) User::where('email', 'bob@example.org')->value('course_id'));
    }

    public function test_choosing_a_course_needs_login(): void
    {
        $this->getJson('/api/courses')->assertUnauthorized();
        $this->putJson('/api/course', ['code' => 'en-es'])->assertUnauthorized();
    }
}
