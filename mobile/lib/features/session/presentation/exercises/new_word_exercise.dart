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
import 'new_word_controller.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/widgets/spanish_peek.dart';

/// Palabra nueva estilo Libreta: la escuchas, la dices y la marcas como aprendida.
class NewWordExercise extends ConsumerStatefulWidget {
  const NewWordExercise({super.key, required this.card, required this.onDone});
  final WordCard card;
  final void Function(ExerciseOutcome) onDone;

  @override
  ConsumerState<NewWordExercise> createState() => _NewWordExerciseState();
}

class _NewWordExerciseState extends ConsumerState<NewWordExercise> {
  @override
  void initState() {
    super.initState();
    ref.read(audioProvider).say(widget.card.word);
  }

  @override
  Widget build(BuildContext context) {
    final provider = newWordControllerProvider(widget.card);
    final s = ref.watch(provider);
    final c = widget.card;
    return StepPage(
      bottom: s.finished
          ? FeedbackBar(ok: s.saved!, title: s.saved! ? tr('¡Nueva palabra!') : tr('No se guardó'), detail: s.saved! ? tr('Mañana la repasas.') : null, onNext: () => widget.onDone(s.outcome))
          : bottomPad(FilledButton(onPressed: s.busy ? null : ref.read(provider.notifier).learn, child: Text(tr('La tengo')))),
      children: [
        stepKind(tr('Palabra nueva')),
        NotebookCard(children: [
          Row(children: [
            Expanded(child: Highlight(c.word, style: W.display(42))),
            IconButton.outlined(tooltip: tr('Escuchar'), icon: const Icon(Icons.volume_up, color: W.accent), onPressed: () => ref.read(audioProvider).say(c.word)),
          ]),
          const SizedBox(height: 8),
          Text(plainExample(c.example), style: const TextStyle(fontSize: 19, height: 1.8)),
          if (c.hideTranslation && c.definition != null) Text('= ${c.definition!}', style: W.hand(28)),
          if (c.hideTranslation)
            SpanishPeek(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.translation, style: W.hand(24, color: W.streak)),
                if (c.exampleEs != null) Text(c.exampleEs!, style: const TextStyle(color: W.muted)),
              ]),
            )
          else ...[
            Text('= ${c.translation}', style: W.hand(28)),
            if (c.exampleEs != null) Text(c.exampleEs!, style: const TextStyle(color: W.muted)),
          ],
        ]),
        const SizedBox(height: 14),
        Text(tr('Dila en voz alta dos veces y úsala en una frase tuya.'), style: TextStyle(color: W.muted)),
      ],
    );
  }
}
