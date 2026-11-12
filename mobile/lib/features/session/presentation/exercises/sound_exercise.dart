import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/feedback_bar.dart';
import '../../../../core/widgets/how_to_say.dart';
import '../../../../core/widgets/mic_button.dart';
import '../../../../core/widgets/step_page.dart';
import '../../data/session_plan.dart';
import 'exercise_outcome.dart';
import 'sound_controller.dart';
import '../../../../core/l10n/tr.dart';

/// Sonido débil: dices la palabra hasta que el sonido sale bien.
class SoundExercise extends ConsumerStatefulWidget {
  const SoundExercise({super.key, required this.step, required this.onDone});
  final SoundStep step;
  final void Function(ExerciseOutcome) onDone;

  @override
  ConsumerState<SoundExercise> createState() => _SoundExerciseState();
}

class _SoundExerciseState extends ConsumerState<SoundExercise> {
  @override
  void initState() {
    super.initState();
    ref.read(audioProvider).say(widget.step.word, slow: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = soundControllerProvider(widget.step);
    final s = ref.watch(provider);
    final w = widget.step;
    return StepPage(
      bottom: s.finished
          ? FeedbackBar(ok: s.passed, title: s.passed ? tr('¡Bien dicho!') : tr('Sigue practicándolo'), detail: '/${w.phoneme}/ al ${s.pct}%', onNext: () => widget.onDone(s.outcome))
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MicButton(recording: s.recording, onPressed: s.recording ? null : ref.read(provider.notifier).attempt),
                const SizedBox(height: 10),
                Text(tr('Toca y dila en voz alta'), style: TextStyle(color: W.muted)),
              ]),
            ),
      children: [
        stepKind(tr('Pronunciación: el sonido /{0}/', [w.phoneme])),
        Row(children: [
          Flexible(child: Text(w.word, style: W.display(46))),
          IconButton(tooltip: tr('Escuchar'), icon: const Icon(Icons.volume_up), onPressed: () => ref.read(audioProvider).say(w.word, slow: true)),
        ]),
        if (s.pct != null) Text(tr('Último intento: {0}%', [s.pct]), style: const TextStyle(color: W.muted)),
        const SizedBox(height: 10),
        if (s.msg.isNotEmpty) Text(s.msg, style: const TextStyle(color: W.warn)),
        // Al fallar, la técnica de este sonido.
        if (s.pct != null && !s.passed && ref.read(provider.notifier).tips.isNotEmpty)
          HowToSay(tips: ref.read(provider.notifier).tips, loading: false, target: w.word),
      ],
    );
  }
}
