import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../../../core/services/word_drill_setting.dart';
import '../../../../core/utils/compare.dart';
import '../../../../core/utils/pron_tips.dart';
import '../../../../core/utils/word_drill.dart';
import '../../../../core/widgets/how_to_say.dart';
import '../../../../core/widgets/word_drill_view.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/session_repository.dart';
import '../../data/word_card.dart';
import 'exercise_outcome.dart';
import '../../../../core/l10n/tr.dart';

class MistakeState {
  const MistakeState({this.recording = false, this.checking = false, this.review, this.tries = 0, this.msg = '', this.xp = 0, this.tips = const [], this.loadingTips = false, this.drill, this.drillDone = false});
  final bool recording, loadingTips;

  /// Mini-taller de la palabra que falló (solo una vez por error, antes del segundo intento).
  final DrillPlan? drill;
  final bool drillDone;

  /// Esperando al servidor: evaluando lo que dijiste.
  final bool checking;

  /// Mientras evalúa o prepara los consejos se muestra el loader en el centro.
  bool get busy => checking || loadingTips;

  /// Cuando no salió: cómo decir las palabras que no se entendieron.
  final List<WordTips> tips;
  final MistakeReview? review;
  final int tries, xp;
  final String msg;

  bool get passed => review?.passed == true;
  bool get finished => review != null && (passed || tries >= 2);
  ExerciseOutcome get outcome => ExerciseOutcome(xp: xp, ok: passed);

  MistakeState copyWith({bool? recording, bool? checking, MistakeReview? review, int? tries, String? msg, int? xp, List<WordTips>? tips, bool? loadingTips, DrillPlan? drill, bool clearDrill = false, bool? drillDone}) => MistakeState(
      recording: recording ?? this.recording,
      checking: checking ?? this.checking,
      review: review ?? this.review,
      tries: tries ?? this.tries,
      msg: msg ?? this.msg,
      xp: xp ?? this.xp,
      tips: tips ?? this.tips,
      loadingTips: loadingTips ?? this.loadingTips,
      drill: clearDrill ? null : (drill ?? this.drill),
      drillDone: drillDone ?? this.drillDone);
}

/// Un error de tus conversaciones: decirlo bien en voz alta (dos intentos).
class MistakeController extends AutoDisposeFamilyNotifier<MistakeState, Mistake> {
  Mistake get mistake => arg;

  @override
  MistakeState build(Mistake mistake) => const MistakeState();

  /// Envía lo que dijiste; devuelve false si no se entendió nada.
  Future<bool> _check(Uint8List wav) async {
    state = state.copyWith(checking: true, msg: '');
    final repo = ref.read(sessionRepositoryProvider);
    // Los consejos se piden A LA VEZ que la nota (no después): si falla, ya están casi listos.
    final tips = repo.pronTips(mistake.correct, wav).timeout(const Duration(seconds: 10)).then<List<WeakWord>?>((w) => w, onError: (_) => null);
    final MistakeReview r;
    try {
      r = await repo.reviewMistake(mistake.id, wav);
    } finally {
      state = state.copyWith(checking: false);
    }
    if (r.silent) {
      state = state.copyWith(msg: tr('No se entendió. Prueba otra vez.'));
      return false;
    }
    state = state.copyWith(review: r, tries: state.tries + 1, xp: state.xp + r.xpGained, msg: '');
    if (!r.passed) await _loadTips(r.heard, tips);
    return true;
  }

  /// No salió: qué sonidos fallaron y cómo decirlos (sin detalle, por la ortografía de lo que faltó).
  Future<void> _loadTips(String heard, Future<List<WeakWord>?> pending) async {
    final target = mistake.correct;
    final missed = [for (final (w, ok) in matchWords(target, heard).tokens) if (!ok) w];
    state = state.copyWith(loadingTips: true);
    final weak = await pending ?? const <WeakWord>[];
    final pairs = weak.isEmpty ? [for (final w in missed) (w, const <String>[])] : [for (final w in weak) (w.word, w.phonemes)];
    // Queda otro intento: antes, practicar aparte la palabra que peor salió (si de verdad no se entendió).
    final drill = !state.finished && !state.drillDone && wordDrillOn(ref) ? pickDrill(weak, target, heard) : null;
    state = state.copyWith(tips: buildTips(pairs), loadingTips: false, drill: drill, drillDone: drill != null ? true : null);
  }

  /// Terminó (o saltó) el mini-taller: vuelve a la frase completa.
  void endDrill() => state = state.copyWith(clearDrill: true);

  Future<void> attempt() async {
    final audio = ref.read(audioProvider);
    if (state.recording || state.busy) return;
    state = state.copyWith(recording: true, msg: '');
    try {
      final rec = await audio.record(maxMs: 15000, silenceMs: 1100);
      // Ya terminó de grabar: el loader sale enseguida (antes de preparar el envío).
      state = state.copyWith(recording: false, checking: rec.heard || rec.maybeVoice);
      if (!rec.heard && !rec.maybeVoice) {
        state = state.copyWith(msg: tr('No te oí. Habla un poco más cerca.'));
      } else if (await _check(rec.wav) && state.drill == null) {
        await audio.say(mistake.correct);
      }
    } catch (e) {
      state = state.copyWith(msg: '$e');
    }
    state = state.copyWith(recording: false);
  }

  /// «Ya terminé»: tocar el micro mientras graba corta sin esperar el silencio.
  void finish() {
    if (state.recording) ref.read(audioProvider).stopRecording();
  }

  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    if (state.finished) return state.outcome;
    await hf.say('You said: ${mistake.said}. Say it the right way:');
    await hf.say(mistake.correct, slow: true);
    while (!state.finished) {
      final h = await hf.listen(maxMs: 15000, silenceMs: 1100, transcribe: false);
      if (h.silent) {
        await hf.say("I didn't hear you. Try again.");
        continue;
      }
      if (!await _check(h.wav!)) {
        await hf.say("Sorry, I didn't understand. Try again.");
        continue;
      }
      final cmd = parseCommand(state.review!.heard);
      if (cmd != null && !state.passed && await handleCommand(hf, Heard(state.review!.heard, cmd), onHelp: () => hf.say(mistake.correct, slow: true))) continue;
      if (state.passed) {
        await hf.say('Perfect!');
      } else {
        final drill = state.drill;
        if (drill != null && !state.finished) {
          await wordDrillHandsFree(hf, ref.read(sessionRepositoryProvider), drill, spanish: ref.read(spanishProvider).step <= 2);
          endDrill();
          await hf.say(mistake.correct, slow: true);
          continue;
        }
        await sayTip(hf, state.tips, spanish: ref.read(spanishProvider).step <= 2);
        await hf.say('Listen.');
        await hf.say(mistake.correct, slow: true);
        await hf.say(mistake.correct);
      }
    }
    return state.outcome;
  }
}

final mistakeControllerProvider = NotifierProvider.autoDispose.family<MistakeController, MistakeState, Mistake>(MistakeController.new);
