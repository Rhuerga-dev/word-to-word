import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../data/session_plan.dart';
import '../../data/session_repository.dart';
import 'exercise_outcome.dart';
import '../../../../core/l10n/tr.dart';

class SoundState {
  const SoundState({this.recording = false, this.tries = 0, this.pct, this.msg = ''});
  final bool recording;
  final int tries;
  final int? pct;
  final String msg;

  bool get passed => (pct ?? 0) >= 80;
  bool get finished => pct != null && (passed || tries >= 3);
  ExerciseOutcome get outcome => ExerciseOutcome(ok: passed);

  SoundState copyWith({bool? recording, int? tries, int? pct, String? msg}) =>
      SoundState(recording: recording ?? this.recording, tries: tries ?? this.tries, pct: pct ?? this.pct, msg: msg ?? this.msg);
}

/// Sonido débil: decir la palabra hasta que el sonido salga bien (o 3 intentos).
class SoundController extends AutoDisposeFamilyNotifier<SoundState, SoundStep> {
  String get word => arg.word;
  String get phoneme => arg.phoneme;

  @override
  SoundState build(SoundStep step) => const SoundState();

  Future<void> _assess(Uint8List wav) async {
    final pct = await ref.read(sessionRepositoryProvider).assess(word, phoneme, wav);
    final tries = state.tries + 1;
    state = state.copyWith(pct: pct, tries: tries, msg: pct < 80 && tries < 3 ? tr('Sonido al {0}%: escúchala otra vez y exagera el movimiento.', [pct]) : '');
  }

  /// Con el dedo: graba y puntúa.
  Future<void> attempt() async {
    final audio = ref.read(audioProvider);
    state = state.copyWith(recording: true, msg: '');
    try {
      final r = await audio.record(maxMs: 3500, silenceMs: 700);
      if (!r.heard) {
        state = state.copyWith(msg: tr('No te oí. Habla un poco más cerca.'));
      } else {
        await _assess(r.wav);
        if (!state.finished) audio.say(word, slow: true);
      }
    } catch (e) {
      state = state.copyWith(msg: '$e');
    }
    state = state.copyWith(recording: false);
  }

  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    var silent = 0;
    await hf.say(word, slow: true);
    while (!state.finished) {
      final h = await hf.listen(maxMs: 3500, silenceMs: 700, transcribe: false);
      if (h.silent) {
        if (++silent >= 3) return ExerciseOutcome.skipped;
        await hf.say("I didn't hear you. Say $word.");
        continue;
      }
      await _assess(h.wav!);
      if (state.passed) {
        await hf.say('Great!');
      } else if (!state.finished) {
        await hf.say('Almost. Listen again.');
        await hf.say(word, slow: true);
      } else {
        await hf.say("Let's keep practicing this one.");
      }
    }
    return state.outcome;
  }
}

final soundControllerProvider = NotifierProvider.autoDispose.family<SoundController, SoundState, SoundStep>(SoundController.new);
