import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/mic_button.dart';
import '../../../../core/widgets/step_page.dart';
import '../../data/session_repository.dart';

/// Sonido débil: dices la palabra hasta que el sonido sale bien (o 3 intentos).
class SoundExercise extends ConsumerStatefulWidget {
  const SoundExercise({super.key, required this.phoneme, required this.word, required this.onNext});
  final String phoneme, word;
  final VoidCallback onNext;

  @override
  ConsumerState<SoundExercise> createState() => _SoundExerciseState();
}

class _SoundExerciseState extends ConsumerState<SoundExercise> {
  bool _rec = false;
  int _tries = 0;
  int? _pct;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    ref.read(audioProvider).say(widget.word, slow: true);
  }

  Future<void> _say() async {
    final audio = ref.read(audioProvider), repo = ref.read(sessionRepositoryProvider);
    setState(() {
      _rec = true;
      _msg = '';
    });
    try {
      final r = await audio.record(maxMs: 3500, silenceMs: 700);
      if (!r.heard) {
        _msg = 'No te oí. Habla un poco más cerca.';
      } else {
        _pct = await repo.assess(widget.word, widget.phoneme, r.wav);
        _tries++;
        if (_pct! < 80 && _tries < 3) {
          _msg = 'Sonido al $_pct%: escúchala otra vez y exagera el movimiento.';
          audio.say(widget.word, slow: true);
        }
      }
    } catch (e) {
      _msg = e.toString();
    }
    if (mounted) setState(() => _rec = false);
  }

  @override
  Widget build(BuildContext context) {
    final done = _pct != null && (_pct! >= 80 || _tries >= 3);
    return StepPage(
      bottom: done
          ? FeedbackBar(ok: _pct! >= 80, title: _pct! >= 80 ? '¡Bien dicho!' : 'Sigue practicándolo', detail: '/${widget.phoneme}/ al $_pct%', onNext: widget.onNext)
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MicButton(recording: _rec, onPressed: _rec ? null : _say),
                const SizedBox(height: 10),
                const Text('Toca y dila en voz alta', style: TextStyle(color: W.muted)),
              ]),
            ),
      children: [
        stepKind('Pronunciación · /${widget.phoneme}/'),
        Row(children: [
          Flexible(child: Text(widget.word, style: W.display(46))),
          IconButton(tooltip: 'Escuchar', icon: const Icon(Icons.volume_up), onPressed: () => ref.read(audioProvider).say(widget.word, slow: true)),
        ]),
        const SizedBox(height: 10),
        if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: W.warn)),
      ],
    );
  }
}
