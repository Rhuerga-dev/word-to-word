import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../data/session_plan.dart';
import '../../data/session_repository.dart';
import 'exercise_outcome.dart';

enum ShadowPhase { loading, ready, recording, checking, result, done, error }

class ShadowState {
  const ShadowState({
    this.phase = ShadowPhase.loading,
    this.title = '',
    this.sentences = const [],
    this.index = 0,
    this.tries = 0,
    this.result,
    this.scores = const [],
    this.hide = false,
    this.msg = '',
    this.error = '',
    this.unitMsg,
  });

  final ShadowPhase phase;
  final String title;
  final List<String> sentences;
  final int index, tries;

  /// Nota de la última grabación de esta frase.
  final ShadowingScore? result;

  /// Mejor nota guardada por frase (null si aún no se logró).
  final List<int?> scores;
  final bool hide;
  final String msg, error;

  /// Mensaje final del paso de la unidad (hecho o el error).
  final String? unitMsg;

  String get sentence => index >= 0 && index < sentences.length ? sentences[index] : '';
  bool get last => index >= sentences.length - 1;
  bool get passed => (result?.score ?? 0) >= 75;

  /// Se puede pasar a la siguiente: se reconoció y aprobó, o se gastaron los 3 intentos.
  bool get canNext => result != null && result!.ok && (passed || tries >= 3);

  /// Promedio de las frases logradas (lo que se manda a la unidad).
  int get avg {
    final s = [for (final x in scores) if (x != null) x];
    return s.isEmpty ? 0 : (s.reduce((a, b) => a + b) / s.length).round();
  }

  ShadowState copyWith({
    ShadowPhase? phase,
    String? title,
    List<String>? sentences,
    int? index,
    int? tries,
    ShadowingScore? result,
    bool clearResult = false,
    List<int?>? scores,
    bool? hide,
    String? msg,
    String? error,
    String? unitMsg,
  }) =>
      ShadowState(
        phase: phase ?? this.phase,
        title: title ?? this.title,
        sentences: sentences ?? this.sentences,
        index: index ?? this.index,
        tries: tries ?? this.tries,
        result: clearResult ? null : (result ?? this.result),
        scores: scores ?? this.scores,
        hide: hide ?? this.hide,
        msg: msg ?? this.msg,
        error: error ?? this.error,
        unitMsg: unitMsg ?? this.unitMsg,
      );
}

/// Shadowing: escuchar una frase y repetirla copiando el ritmo; el servidor la puntúa (Azure).
/// Con unidad del Camino, al terminar marca el paso con el promedio.
class ShadowingController extends AutoDisposeFamilyNotifier<ShadowState, ShadowStep> {
  String? get unitId => arg.unitId;

  @override
  ShadowState build(ShadowStep step) {
    Future.microtask(_load);
    return const ShadowState();
  }

  SessionRepository get _repo => ref.read(sessionRepositoryProvider);

  Future<void> _load() async {
    try {
      final t = await _repo.shadowing(unit: unitId);
      if (t.sentences.isEmpty) {
        state = state.copyWith(phase: ShadowPhase.error, error: tr('No hay texto para practicar ahora.'));
        return;
      }
      state = state.copyWith(phase: ShadowPhase.ready, title: t.title, sentences: t.sentences, scores: List<int?>.filled(t.sentences.length, null));
    } catch (e) {
      state = state.copyWith(phase: ShadowPhase.error, error: '$e');
    }
  }

  /// Vuelve a intentar cargar el texto tras un error.
  Future<void> retry() async {
    state = const ShadowState();
    await _load();
  }

  Future<void> play({bool slow = false}) => ref.read(audioProvider).say(state.sentence, slow: slow);

  void toggleHide() => state = state.copyWith(hide: !state.hide);

  void stop() => ref.read(audioProvider).stopRecording();

  void _keepBest(List<int?> scores, int score) {
    final cur = scores[state.index] ?? 0;
    if (score > cur) scores[state.index] = score;
  }

  /// Con el dedo: graba la frase y la puntúa.
  Future<void> attempt() async {
    if (state.phase == ShadowPhase.recording || state.phase == ShadowPhase.checking) return;
    final audio = ref.read(audioProvider);
    final sentence = state.sentence;
    state = state.copyWith(phase: ShadowPhase.recording, msg: '');
    try {
      final words = sentence.split(' ').length;
      final r = await audio.record(maxMs: 3000 + words * 700, silenceMs: 1000);
      if (!r.heard && !r.maybeVoice) {
        state = state.copyWith(phase: ShadowPhase.ready, msg: tr('No te oí. Habla un poco más cerca.'));
        return;
      }
      state = state.copyWith(phase: ShadowPhase.checking);
      final sc = await _repo.assessShadow(sentence, r.wav);
      if (!sc.ok) {
        // No se reconoció la voz: se muestra el aviso pero no gasta intento.
        state = state.copyWith(phase: ShadowPhase.result, result: sc);
        return;
      }
      final tries = state.tries + 1;
      final scores = [...state.scores];
      if (sc.score >= 75 || tries >= 3) _keepBest(scores, sc.score);
      state = state.copyWith(phase: ShadowPhase.result, result: sc, tries: tries, scores: scores);
    } catch (e) {
      state = state.copyWith(phase: ShadowPhase.ready, msg: '$e');
    }
  }

  /// Siguiente frase; si era la última, cierra (y marca la unidad).
  Future<ExerciseOutcome?> next() async {
    if (state.last) {
      state = state.copyWith(phase: ShadowPhase.done);
      await _finishUnit();
      return ExerciseOutcome.skipped;
    }
    state = state.copyWith(index: state.index + 1, tries: 0, clearResult: true, phase: ShadowPhase.ready, msg: '');
    await play();
    return null;
  }

  Future<void> _finishUnit() async {
    final unit = unitId;
    if (unit == null || state.unitMsg != null) return;
    try {
      await _repo.unitShadowDone(unit, state.avg);
      state = state.copyWith(unitMsg: tr('✓ Shadowing de la unidad completado.'));
    } catch (e) {
      state = state.copyWith(unitMsg: '$e');
    }
  }

  /// Manos libres: escucha cada frase, la lee, te oye repetirla y la puntúa; pasa sola.
  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    if (state.phase == ShadowPhase.loading) await _load();
    if (state.phase == ShadowPhase.error) return ExerciseOutcome.skipped;
    await hf.say('Listen and repeat each sentence.');
    while (state.index < state.sentences.length) {
      final sentence = state.sentence;
      await hf.say(sentence);
      var done = false;
      while (!done) {
        final h = await hf.listen(maxMs: 3000 + sentence.split(' ').length * 700, silenceMs: 1000, transcribe: false);
        if (h.silent) {
          await hf.say('Say it after me.');
          await hf.say(sentence);
          continue;
        }
        state = state.copyWith(phase: ShadowPhase.checking);
        ShadowingScore sc;
        try {
          sc = await _repo.assessShadow(sentence, h.wav!);
        } catch (_) {
          state = state.copyWith(phase: ShadowPhase.result);
          await hf.say("Let's go on.");
          done = true;
          continue;
        }
        if (!sc.ok) {
          state = state.copyWith(phase: ShadowPhase.result, result: sc);
          await hf.say("I didn't catch that. Again.");
          continue;
        }
        final tries = state.tries + 1;
        final scores = [...state.scores];
        if (sc.score >= 75 || tries >= 3) _keepBest(scores, sc.score);
        state = state.copyWith(phase: ShadowPhase.result, result: sc, tries: tries, scores: scores);
        if (sc.score >= 75) {
          await hf.say('Nice!');
          done = true;
        } else if (tries >= 3) {
          await hf.say("Let's keep going.");
          done = true;
        } else {
          await hf.say('Almost. Listen again.');
          await hf.say(sentence, slow: true);
        }
      }
      if (state.last) break;
      state = state.copyWith(index: state.index + 1, tries: 0, clearResult: true, phase: ShadowPhase.ready);
    }
    state = state.copyWith(phase: ShadowPhase.done);
    await _finishUnit();
    return ExerciseOutcome.skipped;
  }
}

final shadowingControllerProvider =
    NotifierProvider.autoDispose.family<ShadowingController, ShadowState, ShadowStep>(ShadowingController.new);
