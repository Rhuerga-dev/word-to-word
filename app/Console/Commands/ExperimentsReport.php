<?php

namespace App\Console\Commands;

use App\Services\BrainyExperiment;
use Illuminate\Console\Command;

/** Informe de un experimento A/B: compara los dos grupos. Solo cifras. */
class ExperimentsReport extends Command
{
    protected $signature = 'experiments:report {experiment : Qué experimento (brainy)} {--json : Salida en JSON}';

    protected $description = 'Compara los grupos de un experimento A/B (práctica real y aprendizaje)';

    public function handle(BrainyExperiment $brainy): int
    {
        if ($this->argument('experiment') !== BrainyExperiment::NAME) {   // lista fija
            $this->error('Experimento desconocido. Disponibles: '.BrainyExperiment::NAME);

            return self::FAILURE;
        }
        $r = $brainy->report();
        if ($this->option('json')) {
            $this->line(json_encode($r, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));

            return self::SUCCESS;
        }

        $b = $r['groups']['brainy'];
        $c = $r['groups']['control'];
        $this->line('Experimento Modo Brainy · '.($r['active'] ? 'EN MARCHA' : 'APAGADO')
            .' · inicio: '.($r['start'] ?? 'sin fecha').' · lleva '.$r['days_running'].' días');
        if ($r['warning']) {
            $this->warn('⚠️  '.$r['warning']);
        }

        $show = fn ($v, string $unit = '') => $v === null ? '—' : $v.$unit;
        $ret = fn (array $x) => $x['percent'] === null ? '— (0)' : "{$x['percent']} % ({$x['active']}/{$x['of']})";
        $acc = fn (array $x, string $of = 'of') => $x['percent'] === null ? '— (0)' : "{$x['percent']} % (de {$x[$of]})";
        $rows = [
            ['Alumnos', $b['users'], $c['users']],
            ['— RETENCIÓN —', '', ''],
            ['Activos el día 1', $ret($b['retention']['d1']), $ret($c['retention']['d1'])],
            ['Activos el día 7', $ret($b['retention']['d7']), $ret($c['retention']['d7'])],
            ['Activos el día 14', $ret($b['retention']['d14']), $ret($c['retention']['d14'])],
            ['Días con práctica / semana', $show($b['practice']['active_days_per_week']), $show($c['practice']['active_days_per_week'])],
            ['— PRÁCTICA REAL (principal) · por alumno y semana —', '', ''],
            ['Sesiones completadas', $show($b['practice']['sessions_per_week']), $show($c['practice']['sessions_per_week'])],
            ['Ejercicios', $show($b['practice']['exercises_per_week']), $show($c['practice']['exercises_per_week'])],
            ['Palabras nuevas', $show($b['practice']['new_words_per_week']), $show($c['practice']['new_words_per_week'])],
            ['Repasos', $show($b['practice']['reviews_per_week']), $show($c['practice']['reviews_per_week'])],
            ['Oído', $show($b['practice']['ear_per_week']), $show($c['practice']['ear_per_week'])],
            ['Minutos hablando', $show($b['practice']['speaking_minutes_per_week']), $show($c['practice']['speaking_minutes_per_week'])],
            ['— APRENDIZAJE (principal) —', '', ''],
            ['Aciertos de Oído', $acc($b['learning']['ear_accuracy']), $acc($c['learning']['ear_accuracy'])],
            ['Aciertos de Vocabulario', $acc($b['learning']['vocab_accuracy']), $acc($c['learning']['vocab_accuracy'])],
            ['Hablar sin errores', $acc($b['learning']['speaking_clean'], 'words'), $acc($c['learning']['speaking_clean'], 'words')],
            ['Palabras bien recordadas / alumno', $show($b['learning']['strong_words_per_user']), $show($c['learning']['strong_words_per_user'])],
            ['— USO DE BRAINY (contexto) —', '', ''],
            ['Modo encendido / apagado', "{$b['brainy']['mode_on']} / {$b['brainy']['mode_off']}", "{$c['brainy']['mode_on']} / {$c['brainy']['mode_off']}"],
            ['Lo encendieron a mano', $b['brainy']['turned_on_by_hand'], $c['brainy']['turned_on_by_hand']],
            ['Lo apagaron a mano', $b['brainy']['turned_off_by_hand'], $c['brainy']['turned_off_by_hand']],
            ['Aperturas de Brainy', $b['brainy']['opens'], $c['brainy']['opens']],
            ['Botones de cuidado', $b['brainy']['care_taps'], $c['brainy']['care_taps']],
        ];
        $this->table(['', 'Grupo Brainy', 'Grupo control'], $rows);
        $this->line('Decide con PRÁCTICA REAL y APRENDIZAJE. Los clics en Brainy solo dan contexto: el grupo Brainy la ve al abrir la app.');

        return self::SUCCESS;
    }
}
