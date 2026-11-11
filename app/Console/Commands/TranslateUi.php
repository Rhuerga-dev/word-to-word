<?php

namespace App\Console\Commands;

use App\Services\ClaudeService;
use App\Services\UiTranslations;
use Illuminate\Console\Command;
use Throwable;

class TranslateUi extends Command
{
    protected $signature = 'i18n:translate {--limit=100}';

    protected $description = 'Traduce con la IA los textos de la interfaz que las apps avisaron que faltan';

    public function handle(UiTranslations $ui, ClaudeService $claude): int
    {
        if (! $claude->enabled()) {
            $this->warn('Sin ANTHROPIC_API_KEY: no se traduce nada.');

            return self::SUCCESS;
        }
        foreach (config('i18n.languages') as $lang) {
            try {
                $n = $ui->translatePending($lang, (int) $this->option('limit'));
                $this->info("{$lang}: {$n} textos traducidos.");
            } catch (Throwable $e) {
                report($e);
                $this->error("{$lang}: {$e->getMessage()}");
            }
        }

        return self::SUCCESS;
    }
}
