import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../path/presentation/path_providers.dart';
import '../../practice/presentation/practice_providers.dart';
import '../../progress/presentation/progress_providers.dart';
import '../../today/presentation/today_providers.dart';
import '../data/session_plan.dart';
import '../data/session_repository.dart';

/// Avance de una sesión.
class SessionState {
  const SessionState({this.index = 0, this.xp = 0, this.right = 0, this.graded = 0, this.ending = false, this.result});
  final int index, xp, right, graded;
  final bool ending;

  /// El resumen del servidor (solo la sesión de Hoy); null mientras se pide.
  final SessionResult? result;

  SessionState copyWith({int? index, int? xp, int? right, int? graded, bool? ending, SessionResult? result}) => SessionState(
        index: index ?? this.index,
        xp: xp ?? this.xp,
        right: right ?? this.right,
        graded: graded ?? this.graded,
        ending: ending ?? this.ending,
        result: result ?? this.result,
      );
}

class SessionController extends AutoDisposeFamilyNotifier<SessionState, SessionPlan> {
  final started = DateTime.now();

  SessionPlan get plan => arg;
  SessionStep get step => plan.steps[state.index];
  double get progress => state.ending ? 1 : state.index / plan.steps.length;
  int get minutes => DateTime.now().difference(started).inMinutes;

  @override
  SessionState build(SessionPlan plan) => const SessionState();

  void gain(int xp) => state = state.copyWith(xp: state.xp + xp);

  void graded(bool ok, int xp) =>
      state = state.copyWith(graded: state.graded + 1, right: state.right + (ok ? 1 : 0), xp: state.xp + xp);

  void next() {
    if (state.index + 1 >= plan.steps.length) {
      finish();
    } else {
      state = state.copyWith(index: state.index + 1);
    }
  }

  Future<void> finish() async {
    state = state.copyWith(ending: true);
    var result = const SessionResult();
    if (plan.daily) {
      try {
        result = await ref.read(sessionRepositoryProvider).complete();
      } catch (_) {}
    }
    state = state.copyWith(result: result);
    // Lo que se ve en las pestañas cambió: que se vuelva a pedir.
    ref
      ..invalidate(todayProvider)
      ..invalidate(pathProvider)
      ..invalidate(practiceProvider)
      ..invalidate(progressProvider);
  }
}

final sessionControllerProvider =
    NotifierProvider.autoDispose.family<SessionController, SessionState, SessionPlan>(SessionController.new);
