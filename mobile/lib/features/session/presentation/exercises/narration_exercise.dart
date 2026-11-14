import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/step_page.dart';
import 'exercise_outcome.dart';
import 'narration_controller.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/widgets/spanish_peek.dart';
import '../../../../core/widgets/w2w_loader.dart';

/// Narración del día, estilo "Llamada": fondo azul, el tema grande y lo que dijiste con su corrección.
class NarrationExercise extends ConsumerWidget {
  const NarrationExercise({super.key, required this.onDone});
  final void Function(ExerciseOutcome) onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(narrationControllerProvider), ctl = ref.read(narrationControllerProvider.notifier);
    final fb = s.feedback;
    const light = TextStyle(color: W.mist, fontSize: 14);
    final white = FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: W.accent, shape: const StadiumBorder());
    final bottom = switch (s.phase) {
      NarrationPhase.ready => bottomPad(FilledButton.icon(style: white, onPressed: ctl.go, icon: const Icon(Icons.mic), label: Text(tr('Empezar a hablar')))),
      NarrationPhase.recording => bottomPad(FilledButton(style: white, onPressed: ctl.stop, child: Text(tr('Terminé de hablar')))),
      NarrationPhase.done => bottomPad(FilledButton(style: white, onPressed: () => onDone(ExerciseOutcome.skipped), child: Text(tr('Continuar')))),
      NarrationPhase.error => bottomPad(Row(children: [
          Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white), onPressed: () => onDone(ExerciseOutcome.skipped), child: Text(tr('Saltar')))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(style: white, onPressed: s.topic == null ? ctl.create : ctl.go, child: Text(tr('Otra vez')))),
        ])),
      _ => null,
    };
    return ColoredBox(
      color: W.accent,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: StepPage(bottom: bottom, children: [
          stepKind(tr('Narración del día: un minuto'), color: W.mist),
          if (s.topic != null) ...[
            Text(tr('Tu coach'), style: light),
            Text(s.topic!.en, style: const TextStyle(fontSize: 22, height: 1.35, color: Colors.white)),
            SpanishPeek(kind: 'hint', color: W.mist, child: Text(s.topic!.es, style: light)),
            const SizedBox(height: 22),
          ],
          switch (s.phase) {
            NarrationPhase.loading => const Center(child: W2WLoader(color: Colors.white)),
            NarrationPhase.ready => Text(tr('Hablas un minuto sin parar, sin preparar nada. Si te quedas en blanco, describe lo que ves y sigue.'), style: TextStyle(fontSize: 17, color: Colors.white)),
            NarrationPhase.recording => Text(tr('Te escucho…'), style: W.display(32, color: W.yellow)),
            NarrationPhase.waiting => Text(tr('Revisando lo que dijiste…'), style: TextStyle(fontSize: 17, color: Colors.white)),
            NarrationPhase.error => Text(s.error, style: const TextStyle(color: W.yellow, fontSize: 16)),
            NarrationPhase.done => const SizedBox.shrink(),
          },
          if (s.phase == NarrationPhase.done && fb != null) ...[
            Text(tr('Tú'), style: light),
            Text(s.said, style: W.display(24, color: Colors.white, weight: FontWeight.w600)),
            const SizedBox(height: 14),
            for (final (said, correct) in fb.fixes)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: W.blueDeep, borderRadius: BorderRadius.circular(14)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: said, style: const TextStyle(decoration: TextDecoration.lineThrough, color: W.mist)),
                  const TextSpan(text: '  →  '),
                  TextSpan(text: correct, style: const TextStyle(color: W.yellow, fontWeight: FontWeight.w700)),
                ])),
              ),
            if (fb.comment != null) ...[
              Text(fb.comment!, style: const TextStyle(fontSize: 16, color: Colors.white)),
              TranslateButton(text: fb.comment!, color: W.mist),
            ],
            if (fb.better != null) ...[
              const SizedBox(height: 14),
              Text(tr('Así sonaría más natural'), style: light),
              Text(fb.better!, style: const TextStyle(fontSize: 17, height: 1.5, color: Colors.white)),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => ref.read(audioProvider).say(fb.better!),
                icon: const Icon(Icons.volume_up),
                label: Text(tr('Escuchar')),
              ),
            ],
          ],
        ]),
      ),
    );
  }
}
