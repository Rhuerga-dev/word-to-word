import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mic_button.dart';
import '../../../../core/widgets/step_page.dart';
import '../../../../core/widgets/w2w_loader.dart';
import '../../data/session_plan.dart';
import 'exercise_outcome.dart';
import 'shadowing_controller.dart';

/// Shadowing: escuchas una frase y la repites copiando el ritmo; cada palabra sale en verde o rojo.
class ShadowingExercise extends ConsumerWidget {
  const ShadowingExercise({super.key, required this.step, required this.onDone});
  final ShadowStep step;
  final void Function(ExerciseOutcome) onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = shadowingControllerProvider(step);
    final s = ref.watch(provider);
    final ctl = ref.read(provider.notifier);

    Future<void> next() async {
      final out = await ctl.next();
      if (out != null) return; // en "done" el botón Continuar es quien cierra
    }

    final bottom = switch (s.phase) {
      ShadowPhase.loading => null,
      ShadowPhase.error => bottomPad(FilledButton(onPressed: ctl.retry, child: Text(tr('Otra vez')))),
      ShadowPhase.checking => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: W2WLoader(label: tr('Evaluando tu pronunciación…')),
        ),
      ShadowPhase.recording => bottomPad(Column(mainAxisSize: MainAxisSize.min, children: [
          MicButton(recording: true, onPressed: null),
          const SizedBox(height: 10),
          Text(tr('Te escucho…'), style: const TextStyle(color: W.muted)),
        ])),
      ShadowPhase.done => bottomPad(FilledButton(onPressed: () => onDone(ExerciseOutcome.skipped), child: Text(tr('Continuar')))),
      ShadowPhase.ready || ShadowPhase.result => s.canNext
          ? bottomPad(FilledButton(onPressed: next, child: Text(s.last ? tr('Terminar') : tr('Siguiente'))))
          : bottomPad(Column(mainAxisSize: MainAxisSize.min, children: [
              MicButton(recording: false, onPressed: ctl.attempt),
              const SizedBox(height: 10),
              Text(s.tries > 0 ? tr('Otra vez') : tr('Toca y repite la frase'), style: const TextStyle(color: W.muted)),
            ])),
    };

    return StepPage(bottom: bottom, children: [
      stepKind(s.title.isEmpty ? tr('Shadowing') : '${tr('Shadowing')} · ${s.title}'),
      if (s.phase == ShadowPhase.loading)
        const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: W2WLoader()))
      else if (s.phase == ShadowPhase.error)
        Padding(padding: const EdgeInsets.only(top: 20), child: Text(s.error, style: const TextStyle(color: W.warn, fontSize: 16)))
      else ...[
        if (s.sentences.isNotEmpty)
          Text(tr('Frase {0} de {1}', [s.index + 1, s.sentences.length]), style: const TextStyle(color: W.muted)),
        const SizedBox(height: 10),
        if (s.phase != ShadowPhase.done) ...[
          Text(
            tr('Escucha y repite justo después, copiando el ritmo y cómo se unen las palabras (no solo las palabras).'),
            style: const TextStyle(color: W.muted),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: W.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: W.line)),
            child: Text(
              s.hide ? tr('🙈 Texto oculto: repítelo de oído') : s.sentence,
              style: W.display(s.hide ? 18 : 24, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => ref.read(audioProvider).say(s.sentence), icon: const Icon(Icons.volume_up), label: Text(tr('Escuchar'))),
            // Sin icono nuevo (la fuente de iconos va recortada en Play): la tortuga va en el texto, como en la web.
            OutlinedButton(onPressed: () => ref.read(audioProvider).say(s.sentence, slow: true), child: Text(tr('🐢 Lento'))),
            TextButton(onPressed: ctl.toggleHide, child: Text(s.hide ? tr('Mostrar texto') : tr('Ocultar texto'))),
          ]),
        ],
        if (s.msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(s.msg, style: const TextStyle(color: W.warn))),
        if (s.result != null) _result(s),
        if (s.phase == ShadowPhase.done) _done(s),
      ],
    ]);
  }

  Widget _result(ShadowState s) {
    final r = s.result!;
    if (!r.ok) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(tr('No te entendí bien. Acércate al micrófono y repítela.'), style: const TextStyle(color: W.warn)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (w, good) in r.words)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (good ? W.good : W.bad).withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
              child: Text(w, style: TextStyle(fontSize: 18, color: good ? W.good : W.bad, fontWeight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _stat('${r.score}%', tr('pronunciación')),
          _stat('${r.fluency}%', tr('fluidez')),
          _stat('${r.accuracy}%', tr('precisión')),
        ]),
        const SizedBox(height: 8),
        Text(
          s.passed
              ? tr('¡Muy bien! Sonó natural.')
              : s.tries >= 3
                  ? tr('Seguimos: vuelve a ella mañana.')
                  : tr('Escúchala otra vez (prueba 🐢 Lento) y repítela.'),
          style: TextStyle(color: s.passed ? W.good : W.muted, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }

  Widget _done(ShadowState s) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('¡Terminaste! Promedio: {0}%', [s.avg]), style: W.display(22, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(tr('Repetir el mismo texto mañana, ya sin mirarlo, es lo que más fija el ritmo.'), style: const TextStyle(color: W.muted)),
          if (s.unitMsg != null) ...[
            const SizedBox(height: 12),
            Text(s.unitMsg!, style: TextStyle(color: s.unitMsg!.startsWith('✓') ? W.good : W.warn, fontWeight: FontWeight.w600)),
          ],
        ]),
      );

  Widget _stat(String big, String small) => Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(big, style: W.display(20, weight: FontWeight.w700)),
          Text(small, style: const TextStyle(color: W.muted, fontSize: 13)),
        ]),
      );
}
