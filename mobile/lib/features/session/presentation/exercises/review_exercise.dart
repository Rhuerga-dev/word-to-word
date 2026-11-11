import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/notebook_card.dart';
import '../../../../core/widgets/step_page.dart';
import '../../data/word_card.dart';
import 'exercise_outcome.dart';
import 'review_controller.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/widgets/spanish_peek.dart';

/// Ficha de repaso estilo Libreta: la dices en voz alta, ves la respuesta y te pones nota.
class ReviewExercise extends ConsumerStatefulWidget {
  const ReviewExercise({super.key, required this.card, required this.onDone});
  final WordCard card;
  final void Function(ExerciseOutcome) onDone;

  @override
  ConsumerState<ReviewExercise> createState() => _ReviewExerciseState();
}

class _ReviewExerciseState extends ConsumerState<ReviewExercise> {
  static const _grades = [('again', 'Olvidé'), ('hard', 'Difícil'), ('good', 'Bien'), ('easy', 'Fácil')];
  static const _defaultDays = {'again': 1, 'hard': 1, 'good': 3, 'easy': 7};

  @override
  void initState() {
    super.initState();
    if (!widget.card.englishOnly) ref.read(audioProvider).say(widget.card.word);
  }

  @override
  Widget build(BuildContext context) {
    final provider = reviewControllerProvider(widget.card);
    final s = ref.watch(provider), ctl = ref.read(provider.notifier);
    final c = widget.card, en = c.englishOnly;
    final Widget bottom;
    if (s.finished) {
      bottom = FeedbackBar(
        ok: s.outcome.ok,
        title: s.error != null ? tr('No se guardó') : (s.grade == 'again' ? tr('La repasarás pronto') : tr('¡Bien!')),
        detail: s.error ?? (c.hideTranslation ? '${c.word}${c.definition != null ? ' · ${c.definition}' : ''}' : '${c.word} · ${c.translation}'),
        onNext: () => widget.onDone(s.outcome),
      );
    } else if (!s.shown) {
      bottom = bottomPad(FilledButton(onPressed: ctl.reveal, child: Text(tr('Ver la respuesta'))));
    } else {
      bottom = bottomPad(Row(children: [
        for (final (g, label) in _grades)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: OutlinedButton(
                onPressed: s.busy ? null : () => ctl.rate(g),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), backgroundColor: g == 'good' ? W.yellow : Colors.white),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(tr(label), style: const TextStyle(fontWeight: FontWeight.w700, color: W.ink)),
                  Text(days(c.previews[g] ?? _defaultDays[g]!), style: const TextStyle(fontSize: 11, color: W.muted)),
                ]),
              ),
            ),
          ),
      ]));
    }
    return StepPage(bottom: bottom, children: [
      stepKind(en && !s.shown ? tr('Solo inglés: ¿qué palabra falta?') : tr('Repaso: ¿qué significa?')),
      NotebookCard(children: [
        if (en && !s.shown) ...[
          if (c.definition != null) Text(c.definition!, style: W.display(22, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(plainExample(c.example, cloze: true), style: const TextStyle(fontSize: 20, height: 1.8)),
        ] else ...[
          Row(children: [
            Expanded(child: Text(c.word, style: W.display(42))),
            IconButton.outlined(tooltip: tr('Escuchar'), icon: const Icon(Icons.volume_up, color: W.accent), onPressed: () => ref.read(audioProvider).say(c.word)),
          ]),
          if (s.shown) ...[
            const SizedBox(height: 6),
            Text(plainExample(c.example), style: const TextStyle(fontSize: 19, height: 1.8)),
            if ((en || c.hideTranslation) && c.definition != null) Text('= ${c.definition!}', style: W.hand(28)),
            if (en || c.hideTranslation)
              SpanishPeek(child: Text(c.translation, style: W.hand(22, color: W.streak)))
            else
              Text('= ${c.translation}', style: W.hand(28)),
          ] else
            Padding(padding: EdgeInsets.only(top: 12), child: Text(tr(c.hideTranslation ? 'Explícalo en voz alta en inglés antes de ver la respuesta.' : 'Dilo en voz alta antes de ver la respuesta.'), style: TextStyle(color: W.muted))),
        ],
      ]),
    ]);
  }
}
