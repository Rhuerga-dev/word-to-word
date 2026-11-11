import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/step_page.dart';
import '../../data/ear_item.dart';
import 'ear_controller.dart';
import 'exercise_outcome.dart';

/// Oído: un altavoz grande, sin la palabra escrita, y tres significados. Rápido, sin traducir.
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
    final ok = s.chosen == e.answer, fast = ok && s.ms <= earFastMs;
    final secs = (s.ms / 1000).toStringAsFixed(1);
    return StepPage(
      bottom: s.finished
          ? FeedbackBar(
              ok: ok,
              title: s.error != null
                  ? tr('No se guardó')
                  : fast
                      ? (s.result!.automatic ? tr('¡Automática! 🎧') : tr('¡Al oído!'))
                      : ok
                          ? tr('Bien, pero tardaste')
                          : tr('Era esta'),
              detail: s.error ?? (fast ? tr('La reconociste en {0} s.', [secs]) : ok ? tr('{0} s: aún la traduces. Mañana otra vez.', [secs]) : tr('Mañana la vuelves a oír.')),
              onNext: () => widget.onDone(ctl.outcome()),
            )
          : null,
      children: [
        stepKind(tr('Oído · ¿qué oíste?')),
        if (widget.first && !s.answered)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(tr('Escucha la palabra y elige qué significa. Rápido, sin traducir: así la reconocerás cuando te la digan.'), style: const TextStyle(color: W.muted)),
          ),
        Center(
          child: Semantics(
            button: true,
            label: tr('Oír otra vez'),
            child: GestureDetector(
              onTap: () => s.answered ? ref.read(audioProvider).say(e.word) : ctl.play(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 130,
                height: 130,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: W.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: W.accent.withValues(alpha: s.playing ? .35 : 0), spreadRadius: s.playing ? 12 : 0)],
                ),
                child: const Icon(Icons.volume_up, color: Colors.white, size: 56),
              ),
            ),
          ),
        ),
        Text(s.answered ? '' : (s.playing ? tr('Escuchando…') : tr('¿Qué significa? Toca la respuesta.')), textAlign: TextAlign.center, style: const TextStyle(color: W.muted)),
        const SizedBox(height: 10),
        if (!s.playing || s.answered)
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
                child: Text(e.options[i], style: const TextStyle(color: W.ink, fontSize: 17, height: 1.3)),
              ),
            ),
        if (s.answered) ...[
          const SizedBox(height: 6),
          Text(e.word, style: W.display(34)),
          if (e.example != null) Text(e.example!, style: const TextStyle(fontSize: 18, height: 1.6)),
        ],
      ],
    );
  }
}
