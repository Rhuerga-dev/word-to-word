import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/services/hands_free.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mic_button.dart';
import '../../../../core/widgets/step_page.dart';
import '../../../../core/widgets/w2w_loader.dart';
import '../../data/session_plan.dart';
import '../../data/session_repository.dart';
import 'conversation_controller.dart';
import 'exercise_outcome.dart';

/// Prueba de la unidad: charlas con la IA en la situación de la unidad y al final te pone nota.
class ConversationExercise extends ConsumerStatefulWidget {
  const ConversationExercise({super.key, required this.step, required this.onDone});
  final ConversationStep step;
  final void Function(ExerciseOutcome) onDone;

  @override
  ConsumerState<ConversationExercise> createState() => _ConversationExerciseState();
}

class _ConversationExerciseState extends ConsumerState<ConversationExercise> {
  @override
  void initState() {
    super.initState();
    // Con manos libres, la sesión conduce por voz; con el dedo, arrancamos aquí.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(handsFreeProvider).on) {
        ref.read(conversationControllerProvider(widget.step).notifier).startTap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = conversationControllerProvider(widget.step);
    final s = ref.watch(provider);
    final ctl = ref.read(provider.notifier);
    final title = widget.step.scenarioTitle.isEmpty ? tr('Prueba de la unidad') : widget.step.scenarioTitle;

    final bottom = switch (s.phase) {
      ConvoPhase.loading || ConvoPhase.aiTurn || ConvoPhase.checking => bottomPad(_waiting(s.status.isEmpty ? tr('Pensando…') : s.status)),
      ConvoPhase.grading => bottomPad(_waiting(tr('Calificando tu conversación…'))),
      ConvoPhase.error => bottomPad(FilledButton(onPressed: ctl.retry, child: Text(tr('Otra vez')))),
      ConvoPhase.listening => bottomPad(Column(mainAxisSize: MainAxisSize.min, children: [
          FilledButton(onPressed: ctl.stopRecording, child: Text(tr('Terminé de hablar'))),
          const SizedBox(height: 6),
          Text(tr('Te escucho…'), style: const TextStyle(color: W.muted)),
        ])),
      ConvoPhase.done => bottomPad(FilledButton(onPressed: () => widget.onDone(ExerciseOutcome.skipped), child: Text(tr('Continuar')))),
      ConvoPhase.ready => bottomPad(Column(mainAxisSize: MainAxisSize.min, children: [
          MicButton(recording: false, onPressed: ctl.listen),
          const SizedBox(height: 8),
          if (s.canFinish)
            TextButton(onPressed: ctl.finish, child: Text(tr('Terminar y evaluar')))
          else
            Text(tr('Habla al menos {0} veces para la nota (llevas {1}).', [ConvoState.minTurns, s.userTurns]), style: const TextStyle(color: W.muted)),
        ])),
    };

    return StepPage(bottom: bottom, children: [
      stepKind('${tr('Prueba')} · $title'),
      if (s.phase == ConvoPhase.error)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(s.error, style: const TextStyle(color: W.warn, fontSize: 16)))
      else if (s.phase == ConvoPhase.loading && s.messages.isEmpty)
        const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: W2WLoader()))
      else ...[
        for (final m in s.messages) _bubble(m),
        if (s.phase == ConvoPhase.done && s.result != null) _result(s.result!),
      ],
    ]);
  }

  Widget _waiting(String label) => Column(mainAxisSize: MainAxisSize.min, children: [
        const W2WLoader(),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: W.muted)),
      ]);

  Widget _bubble(ConvoMsg m) {
    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: m.me ? W.accent : W.card,
        borderRadius: BorderRadius.circular(16),
        border: m.me ? null : Border.all(color: W.line),
      ),
      child: Text(m.text, style: TextStyle(color: m.me ? Colors.white : W.ink, fontSize: 16, height: 1.35)),
    );
    final fb = (m.feedback != null || m.fixes.isNotEmpty)
        ? Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: W.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m.feedback != null) Text(m.feedback!, style: const TextStyle(color: W.muted, fontSize: 14)),
              for (final (said, correct) in m.fixes)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: said, style: const TextStyle(decoration: TextDecoration.lineThrough, color: W.muted)),
                    const TextSpan(text: '  →  '),
                    TextSpan(text: correct, style: const TextStyle(color: W.good, fontWeight: FontWeight.w700)),
                  ])),
                ),
            ]),
          )
        : null;
    return Column(crossAxisAlignment: m.me ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
      Align(alignment: m.me ? Alignment.centerRight : Alignment.centerLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: bubble)),
      if (fb != null) Align(alignment: Alignment.centerLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 340), child: fb)),
    ]);
  }

  Widget _result(UnitTestResult r) {
    final ok = r.passed;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (ok ? W.good : W.warn).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ok ? W.good : W.warn),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Iconos que ya están en la app (la fuente va recortada en Play): parche seguro.
          Icon(ok ? Icons.check : Icons.replay, color: ok ? W.good : W.warn),
          const SizedBox(width: 8),
          Text(ok ? tr('¡Aprobaste la unidad!') : tr('Casi: inténtalo otra vez'), style: W.display(20, weight: FontWeight.w700)),
          const Spacer(),
          if (r.score != null) Text(tr('{0}/10', [r.score]), style: W.display(22, weight: FontWeight.w700, color: ok ? W.good : W.warn)),
        ]),
        const SizedBox(height: 10),
        Text(r.feedback, style: const TextStyle(fontSize: 15, height: 1.5, color: W.ink)),
      ]),
    );
  }
}
