import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/step_page.dart';
import '../../data/session_repository.dart';
import '../../data/word_card.dart';

/// Ficha de repaso: la dices en voz alta, ves la respuesta y te pones nota.
class ReviewExercise extends ConsumerStatefulWidget {
  const ReviewExercise({super.key, required this.card, required this.onGraded, required this.onNext});
  final WordCard card;
  final void Function(bool ok, int xp) onGraded;
  final VoidCallback onNext;

  @override
  ConsumerState<ReviewExercise> createState() => _ReviewExerciseState();
}

class _ReviewExerciseState extends ConsumerState<ReviewExercise> {
  static const _grades = [('again', 'Olvidé'), ('hard', 'Difícil'), ('good', 'Bien'), ('easy', 'Fácil')];
  static const _defaultDays = {'again': 1, 'hard': 1, 'good': 3, 'easy': 7};
  bool _shown = false, _busy = false;
  String? _grade, _error;

  @override
  void initState() {
    super.initState();
    if (!widget.card.englishOnly) ref.read(audioProvider).say(widget.card.word);
  }

  Future<void> _rate(String g) async {
    setState(() => _busy = true);
    try {
      final xp = await ref.read(sessionRepositoryProvider).review(widget.card.id, g);
      widget.onGraded(g != 'again', xp);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _grade = g);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card, en = c.englishOnly;
    final audio = ref.read(audioProvider);
    final Widget bottom;
    if (_grade != null) {
      bottom = FeedbackBar(
        ok: _grade != 'again' && _error == null,
        title: _error != null ? 'No se guardó' : (_grade == 'again' ? 'La repasarás pronto' : '¡Bien!'),
        detail: _error ?? '${c.word} · ${c.translation}',
        onNext: widget.onNext,
      );
    } else if (!_shown) {
      bottom = bottomPad(FilledButton(onPressed: () => setState(() => _shown = true), child: const Text('Ver la respuesta')));
    } else {
      bottom = bottomPad(Row(children: [
        for (final (g, label) in _grades)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: OutlinedButton(
                onPressed: _busy ? null : () => _rate(g),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(days(c.previews[g] ?? _defaultDays[g]!), style: const TextStyle(fontSize: 11, color: W.muted)),
                ]),
              ),
            ),
          ),
      ]));
    }
    return StepPage(bottom: bottom, children: [
      stepKind(en && !_shown ? 'Solo inglés · ¿qué palabra falta?' : 'Repaso · ¿qué significa?'),
      if (en && !_shown) ...[
        if (c.definition != null) Text(c.definition!, style: W.display(22, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(plainExample(c.example, cloze: true), style: const TextStyle(fontSize: 20)),
      ] else ...[
        Row(children: [
          Flexible(child: Text(c.word, style: W.display(46))),
          IconButton(tooltip: 'Escuchar', icon: const Icon(Icons.volume_up), onPressed: () => audio.say(c.word)),
        ]),
        if (_shown) ...[
          const SizedBox(height: 8),
          Text(en && c.definition != null ? c.definition! : c.translation, style: const TextStyle(fontSize: 22, color: W.accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(plainExample(c.example), style: const TextStyle(fontSize: 19)),
          if (en) Text(c.translation, style: const TextStyle(color: W.muted)),
        ],
      ],
      const SizedBox(height: 12),
      if (!_shown) const Text('Dilo en voz alta antes de ver la respuesta.', style: TextStyle(color: W.muted)),
    ]);
  }
}
