<?php

namespace Tests\Feature;

use App\Models\User;
use App\Notifications\StudyReminder;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReminderTest extends TestCase
{
    use RefreshDatabase;

    private function subscribedUser(array $attrs = []): User
    {
        $user = User::factory()->create($attrs + [
            'reminder_enabled' => true,
            'reminder_time' => '19:00',
            'timezone' => 'America/New_York',
        ]);
        $user->updatePushSubscription('https://push.example.com/sub/abc', 'p256dh-key', 'auth-token', 'aes128gcm');

        return $user;
    }

    private function at(string $localTime): void
    {
        $this->travelTo(CarbonImmutable::parse("2026-11-02 $localTime", 'America/New_York'));
    }

    public function test_sends_reminder_at_the_chosen_time_if_not_studied(): void
    {
        Notification::fake();
        $user = $this->subscribedUser();
        $this->at('19:05');

        $this->artisan('reminders:send')->assertSuccessful();

        Notification::assertSentTo($user, StudyReminder::class);
        $this->assertSame('2026-11-02', $user->fresh()->last_reminded_on->toDateString());
    }

    public function test_does_not_send_before_the_time_or_too_late(): void
    {
        Notification::fake();
        $this->subscribedUser();

        $this->at('18:50');
        $this->artisan('reminders:send');
        $this->at('23:30');
        $this->artisan('reminders:send');

        Notification::assertNothingSent();
    }

    public function test_sends_only_once_per_day(): void
    {
        Notification::fake();
        $user = $this->subscribedUser();

        $this->at('19:05');
        $this->artisan('reminders:send');
        $this->at('19:10');
        $this->artisan('reminders:send');

        Notification::assertSentToTimes($user, StudyReminder::class, 1);
    }

    public function test_does_not_send_if_already_studied_today(): void
    {
        Notification::fake();
        $this->at('19:05');
        $this->subscribedUser(['last_study_day' => CarbonImmutable::now(config('vocab.timezone'))->toDateString()]);

        $this->artisan('reminders:send');

        Notification::assertNothingSent();
    }

    public function test_does_not_send_without_subscription_or_when_disabled(): void
    {
        Notification::fake();
        User::factory()->create(['reminder_enabled' => true, 'reminder_time' => '19:00']);
        $this->subscribedUser(['reminder_enabled' => false]);
        $this->at('19:05');

        $this->artisan('reminders:send');

        Notification::assertNothingSent();
    }

    public function test_reminder_text_mentions_streak_and_pending_work(): void
    {
        $n = new StudyReminder(reviews: 4, newWords: 1, streak: 3);

        $this->assertSame('No pierdas tu racha de 3 días', $n->title());
        $this->assertSame('Hoy te esperan 4 repasos y 1 palabra nueva. Son unos minutos.', $n->body());
    }

    public function test_user_can_subscribe_and_set_reminder_time(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/push/subscriptions', [
            'endpoint' => 'https://fcm.googleapis.com/fcm/send/xyz',
            'keys' => ['p256dh' => 'key', 'auth' => 'token'],
        ])->assertNoContent();
        $this->assertSame(1, $user->pushSubscriptions()->count());

        $this->putJson('/api/reminders', ['enabled' => true, 'time' => '08:30', 'timezone' => 'America/Bogota'])
            ->assertOk()
            ->assertJsonPath('reminder.enabled', true)
            ->assertJsonPath('reminder.time', '08:30')
            ->assertJsonPath('reminder.timezone', 'America/Bogota');

        $this->putJson('/api/reminders', ['enabled' => true, 'time' => '25:00', 'timezone' => 'Nowhere/City'])
            ->assertUnprocessable()->assertJsonValidationErrors(['time', 'timezone']);

        $this->deleteJson('/api/push/subscriptions', ['endpoint' => 'https://fcm.googleapis.com/fcm/send/xyz'])->assertNoContent();
        $this->assertSame(0, $user->pushSubscriptions()->count());
    }
}
