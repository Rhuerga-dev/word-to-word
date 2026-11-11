import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/session_plan.dart';
import 'exercises/mistake_exercise.dart';
import 'exercises/narration_exercise.dart';
import 'exercises/new_word_exercise.dart';
import 'exercises/review_exercise.dart';
import 'exercises/sound_exercise.dart';
import 'session_controller.dart';
import 'session_summary.dart';

/// Una sesión: barra de progreso arriba y un ejercicio a la vez.
class SessionPage extends ConsumerWidget {
  const SessionPage({super.key, required this.plan});
  final SessionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sessionControllerProvider(plan);
    final s = ref.watch(provider);
    final c = ref.read(provider.notifier);
    return Scaffold(
      backgroundColor: W.card,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
            child: Row(children: [
              IconButton(tooltip: 'Salir', icon: const Icon(Icons.close), onPressed: () => context.pop()),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: c.progress, minHeight: 14, color: W.good, backgroundColor: W.bg),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(s.xp > 0 ? '+${s.xp}' : '', textAlign: TextAlign.right, style: const TextStyle(color: W.accent, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Expanded(
            child: s.ending
                ? SessionSummary(result: s.result, xp: s.xp, right: s.right, graded: s.graded, minutes: c.minutes, title: plan.title)
                : KeyedSubtree(key: ValueKey(s.index), child: _exercise(c.step, c)),
          ),
        ]),
      ),
    );
  }

  Widget _exercise(SessionStep step, SessionController c) => switch (step) {
        ReviewStep(:final card) => ReviewExercise(card: card, onGraded: c.graded, onNext: c.next),
        NewStep(:final card) => NewWordExercise(card: card, onXp: c.gain, onNext: c.next),
        SoundStep(:final phoneme, :final word) => SoundExercise(phoneme: phoneme, word: word, onNext: c.next),
        NarrateStep() => NarrationExercise(onNext: c.next),
        MistakeStep(:final mistake) => MistakeExercise(mistake: mistake, onXp: c.gain, onNext: c.next),
      };
}
