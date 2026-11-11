import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/hands_free.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hands_free_bar.dart';
import '../data/session_plan.dart';
import 'exercises/exercise_outcome.dart';
import 'exercises/mistake_controller.dart';
import 'exercises/mistake_exercise.dart';
import 'exercises/narration_controller.dart';
import 'exercises/narration_exercise.dart';
import 'exercises/new_word_controller.dart';
import 'exercises/new_word_exercise.dart';
import 'exercises/review_controller.dart';
import 'exercises/review_exercise.dart';
import 'exercises/sound_controller.dart';
import 'exercises/sound_exercise.dart';
import 'session_controller.dart';
import 'session_summary.dart';
import '../../../core/l10n/tr.dart';

/// Una sesión: barra de progreso arriba y un ejercicio a la vez. Con manos libres, todo sigue solo por voz.
class SessionPage extends ConsumerWidget {
  const SessionPage({super.key, required this.plan});
  final SessionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sessionControllerProvider(plan);
    final s = ref.watch(provider);
    final c = ref.read(provider.notifier);
    final hf = ref.watch(handsFreeProvider.select((h) => h.on));
    return Scaffold(
      backgroundColor: W.card,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(children: [
              IconButton(tooltip: tr('Salir'), icon: const Icon(Icons.close), onPressed: () {
                ref.read(handsFreeProvider.notifier).pause();
                context.pop();
              }),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: c.progress, minHeight: 14, color: W.good, backgroundColor: W.bg),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(s.xp > 0 ? '+${s.xp}' : '', textAlign: TextAlign.right, style: const TextStyle(color: W.accent, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: hf ? 'Quitar manos libres' : 'Manos libres',
                isSelected: hf,
                icon: const Icon(Icons.headphones_outlined),
                selectedIcon: const Icon(Icons.headphones, color: W.accent),
                onPressed: () => ref.read(handsFreeProvider.notifier).setOn(!hf),
              ),
            ]),
          ),
          Expanded(
            child: s.ending
                ? SessionSummary(result: s.result, xp: s.xp, right: s.right, graded: s.graded, minutes: c.minutes, title: plan.title)
                : KeyedSubtree(
                    key: ValueKey(s.index),
                    child: _HandsFreeDriver(step: c.step, onDone: c.done, child: _exercise(c.step, c.done)),
                  ),
          ),
          if (hf && !s.ending) const HandsFreeBar(),
        ]),
      ),
    );
  }

  Widget _exercise(SessionStep step, void Function(ExerciseOutcome) done) => switch (step) {
        ReviewStep(:final card) => ReviewExercise(card: card, onDone: done),
        NewStep(:final card) => NewWordExercise(card: card, onDone: done),
        SoundStep() => SoundExercise(step: step, onDone: done),
        NarrateStep() => NarrationExercise(onDone: done),
        MistakeStep(:final mistake) => MistakeExercise(mistake: mistake, onDone: done),
      };
}

/// Con manos libres activado, hace el ejercicio por voz y al terminar pasa al siguiente.
class _HandsFreeDriver extends ConsumerStatefulWidget {
  const _HandsFreeDriver({required this.step, required this.onDone, required this.child});
  final SessionStep step;
  final void Function(ExerciseOutcome) onDone;
  final Widget child;

  @override
  ConsumerState<_HandsFreeDriver> createState() => _HandsFreeDriverState();
}

class _HandsFreeDriverState extends ConsumerState<_HandsFreeDriver> {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(handsFreeProvider).on) _run();
    });
  }

  Future<ExerciseOutcome> _byVoice(HandsFreeController hf) => switch (widget.step) {
        ReviewStep(:final card) => ref.read(reviewControllerProvider(card).notifier).handsFree(hf),
        NewStep(:final card) => ref.read(newWordControllerProvider(card).notifier).handsFree(hf),
        SoundStep() => ref.read(soundControllerProvider(widget.step as SoundStep).notifier).handsFree(hf),
        NarrateStep() => ref.read(narrationControllerProvider.notifier).handsFree(hf),
        MistakeStep(:final mistake) => ref.read(mistakeControllerProvider(mistake).notifier).handsFree(hf),
      };

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    final hf = ref.read(handsFreeProvider.notifier);
    ExerciseOutcome? outcome;
    try {
      outcome = await _byVoice(hf);
    } on HandsFreePaused {
      // Se pausó: el ejercicio sigue con el dedo donde quedó.
    } on SkipExercise {
      outcome = ExerciseOutcome.skipped;
    } catch (e) {
      hf.pause();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Manos libres en pausa: {0}', [e]))));
    } finally {
      _running = false;
      if (ref.read(handsFreeProvider).on) hf.idle();
    }
    if (outcome != null && mounted && ref.read(handsFreeProvider).on) widget.onDone(outcome);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(handsFreeProvider.select((h) => h.on), (_, on) {
      if (on) _run();
    });
    return widget.child;
  }
}
