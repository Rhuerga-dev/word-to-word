<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Models\UserWord;
use App\Notifications\StudyReminder;
use App\Services\ReminderService;
use App\Services\SrsService;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Avisa a quien activó el recordatorio y todavía no estudió hoy.
 * Se ejecuta cada 5 minutos desde el programador (routes/console.php).
 */
class SendStudyReminders extends Command
{
    protected $signature = 'reminders:send';

    protected $description = 'Envía el recordatorio diario de estudio por notificación push';

    public function handle(SrsService $srs): int
    {
        $sent = 0;
        $window = (int) config('vocab.reminder_window_hours', 3);

        User::query()
            ->where('reminder_enabled', true)
            ->whereHas('pushSubscriptions')
            ->chunkById(200, function ($users) use ($srs, $window, &$sent) {
                foreach ($users as $user) {
                    if (! $this->isDue($user, $srs, $window)) {
                        continue;
                    }
                    try {
                        $user->notify($this->buildReminder($user, $srs));
                        $sent++;
                    } catch (Throwable $e) {
                        report($e);
                    }
                    // Marcar aunque falle, para no reintentar cada 5 minutos.
                    $user->forceFill(['last_reminded_on' => $this->localNow($user)->toDateString()])->save();
                }
            });

        $this->info("Recordatorios enviados: {$sent}");

        return self::SUCCESS;
    }

    public function isDue(User $user, SrsService $srs, int $windowHours): bool
    {
        $now = $this->localNow($user);
        // Automático: a su hora habitual (+30 min); si no, la hora que eligió.
        [$h, $m] = array_map('intval', explode(':', app(ReminderService::class)->sendTime($user)));
        $at = $now->setTime($h, $m);

        if ($now->lessThan($at) || $now->greaterThan($at->addHours($windowHours))) {
            return false;
        }
        if ($user->last_reminded_on && $user->last_reminded_on->toDateString() === $now->toDateString()) {
            return false;
        }
        // Si ya estudió hoy, no molestar.
        $today = $srs->today($user);

        return ! ($user->last_study_day && $user->last_study_day->toDateString() === $today->toDateString());
    }

    private function buildReminder(User $user, SrsService $srs): StudyReminder
    {
        $today = $srs->today($user);
        $reviews = UserWord::where('user_id', $user->id)
            ->whereNotNull('introduced_at')
            ->whereDate('next_review', '<=', $today)
            ->count();
        $newDone = (int) DB::table('study_days')->where('user_id', $user->id)
            ->whereDate('day', $today)->value('new_count');
        $streak = $srs->streak($user, $today);
        $word = app(ReminderService::class)->wordOfToday($user);

        return new StudyReminder($reviews, max(0, $user->daily_new - $newDone), $streak, $word);
    }

    private function localNow(User $user): CarbonImmutable
    {
        return CarbonImmutable::now($user->timezone ?: config('vocab.timezone'));
    }
}
