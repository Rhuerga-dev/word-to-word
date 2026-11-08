<?php

namespace App\Services;

use App\Models\User;
use App\Models\UserWord;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * "Probar la demo": each visitor gets their own sample student (level B1, three
 * weeks of history, reviews due today and a streak), so nobody sees anybody
 * else's answers. Demo students are deleted after 24 hours.
 *
 * Limits for demo students: see App\Http\Middleware\DemoGuard.
 */
class DemoService
{
    public const DOMAIN = 'demo.w2w.huergalabs.dev';

    public const LIFETIME_HOURS = 24;

    public function __construct(private LevelService $levels) {}

    public static function isDemo(?User $user): bool
    {
        return $user !== null && str_ends_with($user->email, '@'.self::DOMAIN);
    }

    public function create(): User
    {
        $this->cleanup();

        return DB::transaction(function () {
            $tz = config('vocab.timezone');
            $today = CarbonImmutable::today($tz);

            $user = new User;
            $user->forceFill([
                'name' => 'Invitado',
                'email' => 'demo-'.Str::lower(Str::random(12)).'@'.self::DOMAIN,
                'password' => Str::random(40),      // nobody logs in with it: only with the demo token
                'email_verified_at' => now(),
                'daily_new' => 10,
                'cefr_level' => 'B1',
                'freelance_pack' => true,
                'timezone' => $tz,
                'streak' => 12,
                'last_study_day' => $today->subDay(),
            ])->save();

            DB::table('level_results')->insert([
                'user_id' => $user->id, 'kind' => 'placement', 'level' => 'B1', 'score' => 78,
                'passed' => true, 'new_level' => 'B1',
                'created_at' => now()->subDays(21), 'updated_at' => now()->subDays(21),
            ]);

            $this->history($user, $today);

            return $user;
        });
    }

    /** Deletes demo students older than 24 hours (and their tokens). */
    public function cleanup(): int
    {
        $old = User::where('email', 'like', '%@'.self::DOMAIN)
            ->where('created_at', '<', now()->subHours(self::LIFETIME_HOURS))
            ->pluck('id');
        if ($old->isEmpty()) {
            return 0;
        }
        DB::table('personal_access_tokens')->where('tokenable_type', User::class)->whereIn('tokenable_id', $old)->delete();
        User::whereIn('id', $old)->delete(); // user_words, study_days, etc. go with it (cascade)

        return $old->count();
    }

    /** ~3 weeks of study: A2 words already mastered, B1 words in progress, ~12 reviews due today. */
    private function history(User $user, CarbonImmutable $today): void
    {
        $intervals = config('vocab.intervals');
        $pick = fn (string $level, int $n) => $this->levels->ready($this->levels->inLevel($level))->orderBy('rank')->limit($n)->pluck('id');

        $mastered = $pick('A2', 45);
        $learning = $pick('B1', 85);
        if ($mastered->isEmpty() && $learning->isEmpty()) {
            // Words not imported per level yet: use whatever is ready.
            $all = $this->levels->ready($this->levels->general())->orderBy('rank')->limit(130)->pluck('id');
            [$mastered, $learning] = [$all->take(45), $all->slice(45)];
        }

        mt_srand($user->id);
        $rows = [];
        $perDay = [];
        $add = function (int $wordId, int $level, int $ageDays, int $dueInDays) use (&$rows, &$perDay, $user, $today) {
            $introduced = $today->subDays($ageDays);
            $reviews = max(1, $level + mt_rand(0, 2));
            $rows[] = [
                'user_id' => $user->id, 'word_id' => $wordId, 'level' => $level,
                'introduced_at' => $introduced->toDateString(),
                'next_review' => $today->addDays($dueInDays)->toDateString(),
                'fails' => mt_rand(0, 9) < 3 ? mt_rand(1, 3) : 0,
                'reviews' => $reviews,
                'best_pron_score' => mt_rand(0, 9) < 6 ? mt_rand(62, 98) : null,
                'last_pron_score' => null,
                'created_at' => now(), 'updated_at' => now(),
            ];
            $perDay[$introduced->toDateString()]['new'] = ($perDay[$introduced->toDateString()]['new'] ?? 0) + 1;
            for ($r = 1; $r <= $reviews; $r++) {
                $day = $introduced->addDays(min($ageDays - 1, (int) round($ageDays * $r / ($reviews + 1))))->toDateString();
                $perDay[$day]['rev'] = ($perDay[$day]['rev'] ?? 0) + 1;
            }
        };

        foreach ($mastered->values() as $i => $id) {
            $level = mt_rand(4, count($intervals) - 1);
            $add($id, $level, 21 - intdiv($i, 4) % 6, mt_rand(5, $intervals[$level]));
        }
        foreach ($learning->values() as $i => $id) {
            $age = max(1, 15 - intdiv($i, 6));      // ~6 new words a day for two weeks
            $level = min(3, intdiv(15 - $age, 3) + mt_rand(0, 1));
            $due = $i % 7 === 0 ? 0 : mt_rand(1, $intervals[$level]);   // about 1 in 7 is due today
            $add($id, $level, $age, $due);
        }
        foreach (array_chunk($rows, 200) as $chunk) {
            UserWord::insert($chunk);
        }

        // Study days for the stats and the streak (the last 12 days in a row).
        $days = [];
        foreach ($perDay as $day => $c) {
            $days[$day] = ['user_id' => $user->id, 'day' => $day, 'new_count' => $c['new'] ?? 0, 'review_count' => $c['rev'] ?? 0,
                'created_at' => now(), 'updated_at' => now()];
        }
        for ($d = 1; $d <= 12; $d++) {
            $day = $today->subDays($d)->toDateString();
            $days[$day] ??= ['user_id' => $user->id, 'day' => $day, 'new_count' => 0, 'review_count' => mt_rand(4, 12),
                'created_at' => now(), 'updated_at' => now()];
        }
        unset($days[$today->toDateString()]); // today is for the visitor
        DB::table('study_days')->insert(array_values($days));

        // Sounds that usually trip up Spanish speakers.
        foreach ([['θ', 7, 'think'], ['ð', 5, 'though'], ['æ', 4, 'happy'], ['v', 3, 'very']] as [$ph, $count, $word]) {
            DB::table('phoneme_errors')->insert(['user_id' => $user->id, 'phoneme' => $ph, 'count' => $count, 'last_word' => $word,
                'created_at' => now(), 'updated_at' => now()]);
        }
    }
}
