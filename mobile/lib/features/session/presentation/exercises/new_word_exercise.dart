import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/step_page.dart';
import '../../data/session_repository.dart';
import '../../data/word_card.dart';

/// Palabra nueva: la escuchas, la dices y la marcas como aprendida.
class NewWordExercise extends ConsumerStatefulWidget {
  const NewWordExercise({super.key, required this.card, required this.onXp, required this.onNext});
  final WordCard card;
  final void Function(int xp) onXp;
  final VoidCallback onNext;

  @override
  ConsumerState<NewWordExercise> createState() => _NewWordExerciseState();
}

class _NewWordExerciseState extends ConsumerState<NewWordExercise> {
  bool? _ok;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(audioProvider).say(widget.card.word);
  }

  Future<void> _learn() async {
    setState(() => _busy = true);
    try {
      widget.onXp(await ref.read(sessionRepositoryProvider).learn(widget.card.id));
      _ok = true;
    } catch (_) {
      _ok = false;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    return StepPage(
      bottom: _ok != null
          ? FeedbackBar(ok: _ok!, title: _ok! ? '¡Nueva palabra!' : 'No se guardó', detail: _ok! ? 'Mañana la repasas.' : null, onNext: widget.onNext)
          : bottomPad(FilledButton(onPressed: _busy ? null : _learn, child: const Text('La tengo'))),
      children: [
        stepKind('Palabra nueva'),
        Row(children: [
          Flexible(child: Text(c.word, style: W.display(46))),
          IconButton(tooltip: 'Escuchar', icon: const Icon(Icons.volume_up), onPressed: () => ref.read(audioProvider).say(c.word)),
        ]),
        Text(c.translation, style: const TextStyle(fontSize: 22, color: W.accent, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(plainExample(c.example), style: const TextStyle(fontSize: 19)),
        if (c.exampleEs != null) Text(c.exampleEs!, style: const TextStyle(color: W.muted)),
        const SizedBox(height: 14),
        const Text('Dila en voz alta dos veces y úsala en una frase tuya.', style: TextStyle(color: W.muted)),
      ],
    );
  }
}
