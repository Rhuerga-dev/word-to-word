import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../session/data/session_plan.dart';
import '../../today/data/today.dart';
import '../../today/presentation/today_providers.dart';
import '../data/pet.dart';
import '../data/pet_repository.dart';
import 'pet_providers.dart';
import 'pet_texts.dart';

/// Lo último que le hiciste a Brainy y salió bien: lo agradece al volver.
final petThanksProvider = StateProvider<PetAction?>((ref) => null);

/// Qué ejercicio toca con cada botón cuando no se puede preguntar al servidor (la misma regla que él usa).
String petLocalGo(PetAction action, TodayData d) => switch (action) {
      PetAction.feed => d.newCards.isNotEmpty ? 'new' : (d.reviews.isNotEmpty ? 'reviews' : ''),
      PetAction.play => d.ear.isNotEmpty ? 'ear' : 'sound',
      PetAction.clean => d.reviews.isNotEmpty ? 'reviews' : (d.mistakes.isNotEmpty ? 'mistakes' : ''),
      PetAction.medicine => 'sound',
    };

/// Los ejercicios de W2W de siempre para ese cuidado. null = hoy no hay nada de eso
/// (o hace falta conexión y no la hay: sin ella solo se pueden hacer las fichas).
SessionPlan? petCarePlan(String go, TodayData d, {String? title}) {
  if (d.offline && go != 'new' && go != 'reviews') return null;
  final steps = switch (go) {
    'new' => <SessionStep>[for (final c in d.newCards) NewStep(c)],
    'reviews' => <SessionStep>[for (final c in d.reviews) ReviewStep(c)],
    'ear' => <SessionStep>[for (final e in d.ear) EarStep(e)],
    'mistakes' => <SessionStep>[for (final m in d.mistakes) MistakeStep(m)],
    'sound' => SessionPlan.sound(d.sounds.map(soundKey).whereType<String>().firstOrNull ?? defaultSound()).steps,
    _ => const <SessionStep>[],
  };
  return steps.isEmpty ? null : SessionPlan(steps, title: title);
}

/// Un botón de cuidado: abre el ejercicio que toca y, al volver, refresca a Brainy.
/// Los corazones los da el servidor cuando haces el ejercicio de verdad, no el botón.
Future<void> runPetCare(BuildContext context, WidgetRef ref, PetAction action) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String text) => messenger?.showSnackBar(SnackBar(content: Text(text)));

  final TodayData today;
  try {
    today = await ref.read(todayProvider.future);
  } catch (_) {
    say(petNothingText(PetAction.medicine));
    return;
  }
  final asked = await ref.read(petRepositoryProvider).act(action);
  // Si lo que dice el servidor ya no está en lo de hoy (datos de hace un rato), decide la app.
  final plan = petCarePlan(asked ?? petLocalGo(action, today), today, title: petActionName(action)) ??
      (asked == '' ? null : petCarePlan(petLocalGo(action, today), today, title: petActionName(action)));
  if (!context.mounted) return;
  if (plan == null) {
    say(petNothingText(action));
    return;
  }
  ref.read(petThanksProvider.notifier).state = null;
  await context.push(Routes.session, extra: plan);

  // De vuelta: si la sesión se terminó (hay más puntos que antes), Brainy lo agradece.
  ref.invalidate(petProvider);
  try {
    final after = await ref.read(todayProvider.future);
    if (after.xp.xp > today.xp.xp) ref.read(petThanksProvider.notifier).state = action;
  } catch (_) {}
}
