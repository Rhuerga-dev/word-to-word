<?php

namespace App\Console\Commands;

use App\Services\UiTranslations;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

/**
 * Pasa a lang/{idioma}.json (en git) lo que la IA tradujo sola en storage/app/i18n/.
 * Se corre a mano cuando se quieren fijar esas traducciones; luego hay que hacer commit.
 */
class PromoteUiTranslations extends Command
{
    protected $signature = 'i18n:promote';

    protected $description = 'Copia a lang/ (git) las traducciones que hizo la IA y vacía su archivo';

    public function handle(UiTranslations $ui): int
    {
        foreach (config('i18n.languages') as $lang) {
            $learned = $ui->learned($lang);
            $ui->merge($lang, $learned, reviewed: true);
            File::delete(rtrim(config('i18n.learned_path'), '/')."/{$lang}.json");
            $this->info("{$lang}: ".count($learned).' textos pasados a lang/. Revisa el cambio y haz commit.');
        }

        return self::SUCCESS;
    }
}
