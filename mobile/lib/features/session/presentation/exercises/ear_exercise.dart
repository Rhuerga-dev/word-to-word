import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/step_page.dart';
import '../../data/ear_item.dart';
import 'ear_controller.dart';
import 'exercise_outcome.dart';

const _stepNames = {'sound': 'Sonido', 'easy': 'Significado fácil', 'definition': 'Definición', 'sentence': 'En una frase', 'fast': 'Rápido'};
const _prompts = {
  'sound': '¿Qué palabra oíste?',
  'easy': '¿Qué significa? Toca la respuesta.',
  'definition': '¿Qué significa? Toca la respuesta.',
  'sentence': 'Oíste una frase y luego la palabra. ¿Qué significa la palabra?',
  'fast': '¿Qué significa? Rápido: tienes 2 segundos.',
};

/// Oído por escalones: un altavoz grande, sin la palabra escrita, y tres opciones.
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
    final ok = s.chosen == e.answer, fast = ctl.fast;
    final secs = (s.ms / 1000).toStringAsFixed(1);
    final up = fast && s.result?.mode != null && s.result!.mode != e.mode ? ' ${tr('Sube a: {0}.', [tr(_stepNames[s.result!.mode] ?? '')])}' : '';
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
              detail: s.error ??
                  (fast
                      ? tr('La reconociste en {0} s.', [secs]) + up
                      : ok
                          ? tr('{0} s: aún la traduces. Mañana otra vez.', [secs])
                          : tr('Mañana la vuelves a oír, un escalón más fácil.')),
              onNext: () => widget.onDone(ctl.outcome()),
            )
          : null,
      children: [
        stepKind('${tr('Oído')} · ${tr(_stepNames[e.mode] ?? '')}'),
        // Escalón de esta palabra (1 a 5).
        Row(children: [
          for (var k = 1; k <= 5; k++)
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
              tr('Cada palabra sube por escalones: primero reconoces el sonido, luego lo que significa, después dentro de una frase y al final sin pensar. Rápido y sin traducir.'),
              style: const TextStyle(color: W.muted),
            ),
          ),
        Center(
          child: Semantics(
            button: true,
            label: tr('Oír otra vez'),
            child: GestureDetector(
              onTap: s.playing ? null : ctl.play,
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
          Text(
            s.playing && s.endedAt == null ? tr('Escuchando…') : (s.lens ? tr('Toca la palabra que no entiendes.') : tr(_prompts[e.mode] ?? '')),
            textAlign: TextAlign.center,
            style: const TextStyle(color: W.muted),
          ),
        const SizedBox(height: 10),
        if (s.endedAt != null || s.answered)
          for (var i = 0; i < e.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: s.lens
                  ? _LensOption(text: e.options[i], onWord: ctl.lookUp)
                  : OutlinedButton(
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
        if (e.definitions && !s.answered && s.endedAt != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: ctl.toggleLens, child: Text(s.lens ? tr('✓ Listo, ya entiendo') : tr('🔍 No entiendo una palabra'))),
          ),
        if (s.look != null && !s.answered)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: W.accent.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
            child: Text(s.look!, style: const TextStyle(fontSize: 17)),
          ),
        if (s.answered && e.mode != 'sound') ...[
          const SizedBox(height: 6),
          Text(e.word, style: W.display(34)),
          if (e.example != null) Text(e.example!, style: const TextStyle(fontSize: 18, height: 1.6)),
        ],
      ],
    );
  }
}

/// Una opción en modo lupa: cada palabra se puede tocar para ver su significado simple.
class _LensOption extends StatelessWidget {
  const _LensOption({required this.text, required this.onWord});
  final String text;
  final void Function(String) onWord;

  @override
  Widget build(BuildContext context) {
    final words = RegExp(r"[A-Za-z][A-Za-z'’-]*").allMatches(text).map((m) => m.group(0)!).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: W.line, width: 2)),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final w in words)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onWord(w),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: W.accent.withValues(alpha: .08), borderRadius: BorderRadius.circular(8)),
              child: Text(w, style: const TextStyle(fontSize: 17, color: W.ink, decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted)),
            ),
          ),
      ]),
    );
  }
}
