import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/how_to_say.dart';
import '../../../../core/widgets/mic_button.dart';
import '../../../../core/widgets/step_page.dart';
import '../../../../core/widgets/w2w_loader.dart';
import '../../../../core/widgets/word_drill_view.dart';
import '../../data/word_card.dart';
import 'exercise_outcome.dart';
import 'mistake_controller.dart';
import '../../../../core/l10n/tr.dart';

/// Un error de tus conversaciones: lo dices bien en voz alta.
class MistakeExercise extends ConsumerWidget {
  const MistakeExercise({super.key, required this.mistake, required this.onDone});
  final Mistake mistake;
  final void Function(ExerciseOutcome) onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mistakeControllerProvider(mistake);
    final s = ref.watch(provider), r = s.review, m = mistake;
    // Falló una palabra: mini-taller de esa palabra y luego vuelve aquí para decir la frase completa.
    if (s.drill != null && !ref.watch(handsFreeProvider.select((h) => h.on))) {
      return WordDrillView(key: ValueKey('drill-${s.drill!.word}'), plan: s.drill!, onDone: ref.read(provider.notifier).endDrill);
    }
    final page = StepPage(
      bottom: s.finished
          ? FeedbackBar(ok: s.passed, title: s.passed ? tr('¡Bien dicho!') : tr('Vuelve mañana'), detail: m.correct, onNext: () => onDone(s.outcome))
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MicButton(recording: s.recording, onPressed: s.busy ? null : (s.recording ? ref.read(provider.notifier).finish : ref.read(provider.notifier).attempt)),
                const SizedBox(height: 10),
                Text(s.recording ? tr('Te escucho… toca al terminar') : (r == null ? tr('Dilo bien en voz alta') : tr('Otra vez')), style: const TextStyle(color: W.muted)),
              ]),
            ),
      children: [
        stepKind(tr('Tus errores: dilo bien')),
        Text(tr('Dijiste:'), style: const TextStyle(color: W.muted)),
        Text(m.said, style: const TextStyle(fontSize: 22, decoration: TextDecoration.lineThrough, color: W.bad)),
        if (m.why != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('💡 ${m.why}', style: const TextStyle(color: W.muted))),
        const SizedBox(height: 14),
        Text(tr('Dilo así:'), style: const TextStyle(color: W.muted)),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text(m.correct, key: const ValueKey('mistake-correct'), style: W.display(22, color: W.good, weight: FontWeight.w600))),
          IconButton(tooltip: tr('Escuchar'), icon: const Icon(Icons.volume_up), onPressed: () => ref.read(audioProvider).say(m.correct, slow: true)),
        ]),
        if (r != null && !s.passed) ...[
          const SizedBox(height: 8),
          Text(tr('Entendí: “{0}”', [r.heard]), style: const TextStyle(color: W.muted)),
        ],
        if (!s.passed && (s.loadingTips || s.tips.isNotEmpty)) HowToSay(tips: s.tips, loading: s.loadingTips, target: m.correct),
        if (s.msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(s.msg, style: const TextStyle(color: W.warn))),
      ],
    );
    return Stack(children: [
      page,
      if (s.busy) Positioned.fill(child: _Evaluating(label: s.checking ? tr('Evaluando tu pronunciación…') : tr('Preparando cómo decirlo mejor…'))),
    ]);
  }
}

/// Velo con el loader de W2W en el centro mientras el servidor evalúa (tapa la pantalla y no deja tocar).
class _Evaluating extends StatelessWidget {
  const _Evaluating({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
        key: const ValueKey('mistake-evaluating'),
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
        child: Center(child: W2WLoader(label: label)),
      );
}
