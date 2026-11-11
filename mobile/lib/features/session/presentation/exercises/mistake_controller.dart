import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../data/session_repository.dart';
import '../../data/word_card.dart';
import 'exercise_outcome.dart';
import '../../../../core/l10n/tr.dart';

class MistakeState {
  const MistakeState({this.recording = false, this.review, this.tries = 0, this.msg = '', this.xp = 0});
  final bool recording;
  final MistakeReview? review;
  final int tries, xp;
  final String msg;

  bool get passed => review?.passed == true;
  bool get finished => review != null && (passed || tries >= 2);
  ExerciseOutcome get outcome => ExerciseOutcome(xp: xp, ok: passed);

  MistakeState copyWith({bool? recording, MistakeReview? review, int? tries, String? msg, int? xp}) => MistakeState(
      recording: recording ?? this.recording, review: review ?? this.review, tries: tries ?? this.tries, msg: msg ?? this.msg, xp: xp ?? this.xp);
}

/// Un error de tus conversaciones: decirlo bien en voz alta (dos intentos).
class MistakeController extends AutoDisposeFamilyNotifier<MistakeState, Mistake> {
  Mistake get mistake => arg;

  @override
  MistakeState build(Mistake mistake) => const MistakeState();

  /// Envía lo que dijiste; devuelve false si no se entendió nada.
  Future<bool> _check(Uint8List wav) async {
    final r = await ref.read(sessionRepositoryProvider).reviewMistake(mistake.id, wav);
    if (r.silent) {
      state = state.copyWith(msg: tr('No se entendió. Prueba otra vez.'));
      return false;
    }
    state = state.copyWith(review: r, tries: state.tries + 1, xp: state.xp + r.xpGained, msg: '');
    return true;
  }

  Future<void> attempt() async {
    final audio = ref.read(audioProvider);
    state = state.copyWith(recording: true, msg: '');
    try {
      final rec = await audio.record(maxMs: 15000, silenceMs: 1400);
      if (!rec.heard) {
        state = state.copyWith(msg: tr('No te oí. Habla un poco más cerca.'));
      } else if (await _check(rec.wav)) {
        await audio.say(mistake.correct);
      }
    } catch (e) {
      state = state.copyWith(msg: '$e');
    }
    state = state.copyWith(recording: false);
  }

  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    if (state.finished) return state.outcome;
    await hf.say('You said: ${mistake.said}. Say it the right way.');
    while (!state.finished) {
      final h = await hf.listen(maxMs: 15000, silenceMs: 1400, transcribe: false);
      if (h.silent) {
        await hf.say("I didn't hear you. Try again.");
        continue;
      }
      if (!await _check(h.wav!)) {
        await hf.say("I didn't understand. Try again.");
        continue;
      }
      final cmd = parseCommand(state.review!.heard);
      if (cmd != null && !state.passed && await handleCommand(hf, Heard(state.review!.heard, cmd), onHelp: () => hf.say(mistake.correct, slow: true))) continue;
      if (state.passed) {
        await hf.say('Perfect!');
      } else {
        await hf.say('Listen.');
        await hf.say(mistake.correct);
      }
    }
    return state.outcome;
  }
}

final mistakeControllerProvider = NotifierProvider.autoDispose.family<MistakeController, MistakeState, Mistake>(MistakeController.new);
