import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/mic_button.dart';
import '../../../../core/widgets/step_page.dart';
import '../../data/session_repository.dart';
import '../../data/word_card.dart';

/// Un error de tus conversaciones: lo dices bien en voz alta (dos intentos).
class MistakeExercise extends ConsumerStatefulWidget {
  const MistakeExercise({super.key, required this.mistake, required this.onXp, required this.onNext});
  final Mistake mistake;
  final void Function(int xp) onXp;
  final VoidCallback onNext;

  @override
  ConsumerState<MistakeExercise> createState() => _MistakeExerciseState();
}

class _MistakeExerciseState extends ConsumerState<MistakeExercise> {
  bool _rec = false;
  MistakeReview? _r;
  String _msg = '';
  int _tries = 0;

  Future<void> _say() async {
    final audio = ref.read(audioProvider), repo = ref.read(sessionRepositoryProvider);
    setState(() {
      _rec = true;
      _msg = '';
    });
    try {
      final rec = await audio.record(maxMs: 15000, silenceMs: 1400);
      if (!rec.heard) {
        _msg = 'No te oí. Habla un poco más cerca.';
      } else {
        final r = await repo.reviewMistake(widget.mistake.id, rec.wav);
        if (r.silent) {
          _msg = 'No se entendió. Prueba otra vez.';
        } else {
          _r = r;
          _tries++;
          widget.onXp(r.xpGained);
          await audio.say(widget.mistake.correct);
        }
      }
    } catch (e) {
      _msg = e.toString();
    }
    if (mounted) setState(() => _rec = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mistake, r = _r, passed = r?.passed == true;
    final done = r != null && (passed || _tries >= 2);
    return StepPage(
      bottom: done
          ? FeedbackBar(ok: passed, title: passed ? '¡Bien dicho!' : 'Vuelve mañana', detail: m.correct, onNext: widget.onNext)
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MicButton(recording: _rec, onPressed: _rec ? null : _say),
                const SizedBox(height: 10),
                Text(r == null ? 'Dilo bien en voz alta' : 'Otra vez', style: const TextStyle(color: W.muted)),
              ]),
            ),
      children: [
        stepKind('Tus errores · dilo bien'),
        const Text('Dijiste:', style: TextStyle(color: W.muted)),
        Text(m.said, style: const TextStyle(fontSize: 22, decoration: TextDecoration.lineThrough, color: W.bad)),
        if (m.why != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('💡 ${m.why}', style: const TextStyle(color: W.muted))),
        if (r != null && !passed) ...[
          const SizedBox(height: 12),
          Text('Entendí: “${r.heard}”', style: const TextStyle(color: W.muted)),
          Text(m.correct, style: W.display(22, color: W.good, weight: FontWeight.w600)),
        ],
        if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_msg, style: const TextStyle(color: W.warn))),
      ],
    );
  }
}
