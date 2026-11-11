import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/session_controller.dart';
import '../models/session_plan.dart';
import 'steps/mistake_step_view.dart';
import 'steps/narrate_step_view.dart';
import 'steps/new_word_step_view.dart';
import 'steps/review_step_view.dart';
import 'steps/session_end_view.dart';
import 'steps/sound_step_view.dart';

/// Una sesión: barra de progreso arriba y un ejercicio a la vez.
class SessionView extends GetView<SessionController> {
  const SessionView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: W.card,
      body: SafeArea(
        child: Obx(() => Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                child: Row(children: [
                  IconButton(tooltip: 'Salir', icon: const Icon(Icons.close), onPressed: () => Get.back(result: true)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: c.progress, minHeight: 14, color: W.good, backgroundColor: W.bg),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(c.xp.value > 0 ? '+${c.xp.value}' : '', textAlign: TextAlign.right, style: const TextStyle(color: W.accent, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              Expanded(
                child: c.ending.value
                    ? SessionEndView(data: c.end.value, xp: c.xp.value, right: c.right, graded: c.graded, minutes: c.minutes, title: c.plan.title)
                    : KeyedSubtree(key: ValueKey(c.index.value), child: _stepView(c.step)),
              ),
            ])),
      ),
    );
  }

  Widget _stepView(SessionStep s) => switch (s) {
        ReviewStep(:final card) => ReviewStepView(card: card, onGraded: controller.graded1, onNext: controller.next),
        NewStep(:final card) => NewWordStepView(card: card, onXp: controller.gain, onNext: controller.next),
        SoundStep(:final phoneme, :final word) => SoundStepView(phoneme: phoneme, word: word, onNext: controller.next),
        NarrateStep() => NarrateStepView(onNext: controller.next),
        MistakeStep(:final mistake) => MistakeStepView(mistake: mistake, onXp: controller.gain, onNext: controller.next),
      };
}
