import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/mic_button.dart';
import '../../../../core/widgets/step_page.dart';
import '../../data/ear_item.dart';
import 'ear_controller.dart';
import 'exercise_outcome.dart';

const _stepNames = {
  'sound': 'Sonido',
  'easy': 'Significado fácil',
  'repeat_word': 'Repite la palabra',
  'repeat_phrase': 'Repite la frase',
  'repeat_sentence': 'Repite la oración',
  'repeat_long': 'Oración larga',
};
const _prompts = {
  'sound': '¿Qué palabra oíste?',
  'easy': '¿Qué significa? Toca la respuesta.',
  'repeat_word': 'Escucha y repite la palabra.',
  'repeat_phrase': 'Escucha y repite la frase.',
  'repeat_sentence': 'Escucha y repite la oración.',
  'repeat_long': 'Escucha y repite la oración completa.',
};

/// Oído por escalones: primero escuchas y tocas; después escuchas y repites, cada vez algo más largo.
class EarExercise extends ConsumerStatefulWidget {
  const EarExercise({super.key, required this.item, required this.onDone, this.first = false});
  final EarItem item;
  final void Function(ExerciseOutcome) onDone;

  /// El primero de la sesión explica qué hacer.
  final bool first;

  @override
  ConsumerState<EarExercise> createState() => _EarExerciseState();
}

class _EarExerciseState extends ConsumerState<EarExercise> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(earControllerProvider(widget.item).notifier).play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = earControllerProvider(widget.item);
    final s = ref.watch(provider), ctl = ref.read(provider.notifier), e = widget.item;
    final ok = ctl.passed, fast = ctl.fast;
    final secs = (s.ms / 1000).toStringAsFixed(1);
    final up = fast && s.result?.mode != null && s.result!.mode != e.mode ? ' ${tr('Sube a: {0}.', [tr(_stepNames[s.result!.mode] ?? '')])}' : '';
    final pct = s.match?.pct ?? 0;
    final String detail;
    if (s.error != null) {
      detail = s.error!;
    } else if (e.isRepeat) {
      detail = ok ? tr('Dijiste bien el {0}% de las palabras.', [pct]) + up : tr('Mañana la vuelves a oír, un escalón más fácil.');
    } else {
      detail = fast ? tr('La reconociste en {0} s.', [secs]) + up : ok ? tr('{0} s: aún la traduces. Mañana otra vez.', [secs]) : tr('Mañana la vuelves a oír, un escalón más fácil.');
    }
    final title = s.error != null
        ? tr('No se guardó')
        : e.isRepeat
            ? (ok ? (s.result?.automatic == true ? tr('¡Automática! 🎧') : (pct >= 100 ? tr('¡Perfecto!') : tr('¡Bien dicho!'))) : tr('Sigue practicándolo'))
            : fast
                ? (s.result!.automatic ? tr('¡Automática! 🎧') : tr('¡Al oído!'))
                : ok
                    ? tr('Bien, pero tardaste')
                    : tr('Era esta');

    return StepPage(
      bottom: s.finished
          ? FeedbackBar(ok: ok, title: title, detail: detail, onNext: () => widget.onDone(ctl.outcome()))
          : e.isRepeat && s.endedAt != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    MicButton(recording: s.recording, onPressed: s.recording || s.checking || s.playing ? null : ctl.attempt),
                    const SizedBox(height: 8),
                    Text(
                      s.checking ? tr('Revisando lo que dijiste…') : (s.recording ? tr('Te escucho…') : (s.tries > 0 ? tr('Otra vez') : tr('Toca y repite'))),
                      style: const TextStyle(color: W.muted),
                    ),
                  ]),
                )
              : null,
      children: [
        stepKind('${tr('Oído')} · ${tr(_stepNames[e.mode] ?? '')}'),
        // Escalón de esta palabra (1 a 6).
        Row(children: [
          for (var k = 1; k <= earSteps.length; k++)
            Expanded(
              child: Container(
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: k <= e.step ? W.accent : W.line, borderRadius: BorderRadius.circular(9)),
              ),
            ),
        ]),
        if (widget.first && !s.answered)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr('Cada palabra sube por escalones: primero la reconoces y sabes qué significa; después la repites, luego en una frase, en una oración y en una oración larga.'),
              style: const TextStyle(color: W.muted),
            ),
          ),
        Center(
          child: Semantics(
            button: true,
            label: tr('Oír otra vez'),
            child: GestureDetector(
              onTap: s.playing || s.recording ? null : ctl.play,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 120,
                height: 120,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: W.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: W.accent.withValues(alpha: s.playing ? .35 : 0), spreadRadius: s.playing ? 12 : 0)],
                ),
                child: const Icon(Icons.volume_up, color: Colors.white, size: 52),
              ),
            ),
          ),
        ),
        if (!s.answered)
          Text(s.playing && s.endedAt == null ? tr('Escuchando…') : tr(_prompts[e.mode] ?? ''), textAlign: TextAlign.center, style: const TextStyle(color: W.muted)),
        const SizedBox(height: 10),
        // Escalones de tocar: las opciones.
        if (!e.isRepeat && (s.endedAt != null || s.answered))
          for (var i = 0; i < e.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  backgroundColor: s.answered && i == e.answer ? W.good.withValues(alpha: .14) : (s.chosen == i && !ok ? W.bad.withValues(alpha: .14) : Colors.white),
                  side: BorderSide(color: s.answered && i == e.answer ? W.good : (s.chosen == i && !ok ? W.bad : W.line), width: 2),
                ),
                onPressed: s.answered ? null : () => ctl.choose(i),
                child: Text(e.options[i], style: TextStyle(color: W.ink, fontSize: e.mode == 'sound' ? 22 : 17, height: 1.3)),
              ),
            ),
        // Escalones de repetir: qué palabras salieron bien.
        if (e.isRepeat && s.match != null) ...[
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (final (w, good) in s.match!.tokens)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: (good ? W.good : W.bad).withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
                child: Text(w, style: TextStyle(fontSize: 18, color: good ? W.good : W.bad, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 6),
          Text('${tr('Entendí: “{0}”', [s.heard])} · ${s.match!.pct}%', textAlign: TextAlign.center, style: const TextStyle(color: W.muted)),
        ],
        if (s.msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.msg, textAlign: TextAlign.center, style: const TextStyle(color: W.warn))),
        if (s.answered) ...[
          const SizedBox(height: 10),
          if (e.isRepeat) ...[
            Text(e.target ?? e.word, style: W.display(e.mode == 'repeat_word' ? 34 : 22, weight: FontWeight.w700)),
            if ((e.meaning2 ?? '').isNotEmpty) Text('${e.word} = ${e.meaning2}', style: const TextStyle(color: W.muted, fontSize: 16)),
          ] else if (e.mode != 'sound') ...[
            Text(e.word, style: W.display(34)),
            if (e.example != null) Text(e.example!, style: const TextStyle(fontSize: 18, height: 1.6)),
          ],
        ],
      ],
    );
  }
}
