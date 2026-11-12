import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/how_to_say.dart';
import '../../../../core/widgets/mic_button.dart';
import '../../../../core/widgets/step_page.dart';
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
    return StepPage(
      bottom: s.finished
          ? FeedbackBar(ok: s.passed, title: s.passed ? tr('¡Bien dicho!') : tr('Vuelve mañana'), detail: m.correct, onNext: () => onDone(s.outcome))
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MicButton(recording: s.recording, onPressed: s.recording ? null : ref.read(provider.notifier).attempt),
                const SizedBox(height: 10),
                Text(r == null ? tr('Dilo bien en voz alta') : tr('Otra vez'), style: const TextStyle(color: W.muted)),
              ]),
            ),
      children: [
        stepKind(tr('Tus errores: dilo bien')),
        Text(tr('Dijiste:'), style: const TextStyle(color: W.muted)),
        Text(m.said, style: const TextStyle(fontSize: 22, decoration: TextDecoration.lineThrough, color: W.bad)),
        if (m.why != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('💡 ${m.why}', style: const TextStyle(color: W.muted))),
        if (r != null && !s.passed) ...[
          const SizedBox(height: 12),
          Text(tr('Entendí: “{0}”', [r.heard]), style: const TextStyle(color: W.muted)),
          Text(m.correct, style: W.display(22, color: W.good, weight: FontWeight.w600)),
        ],
        if (!s.passed && (s.loadingTips || s.tips.isNotEmpty)) HowToSay(tips: s.tips, loading: s.loadingTips, target: m.correct),
        if (s.msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(s.msg, style: const TextStyle(color: W.warn))),
      ],
    );
  }
}
