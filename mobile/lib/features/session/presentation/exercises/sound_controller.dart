import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../../../core/utils/pron_tips.dart';
import '../../../../core/widgets/how_to_say.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/session_plan.dart';
import '../../data/session_repository.dart';
import 'exercise_outcome.dart';
import '../../../../core/l10n/tr.dart';

class SoundState {
  const SoundState({this.recording = false, this.checking = false, this.tries = 0, this.pct, this.msg = ''});
  final bool recording;

  /// El servidor está puntuando: ya no se graba (así el micro no se queda "en rojo").
  final bool checking;
  final int tries;
  final int? pct;
  final String msg;

  bool get passed => (pct ?? 0) >= 80;
  bool get finished => pct != null && (passed || tries >= 3);
  ExerciseOutcome get outcome => ExerciseOutcome(ok: passed);

  SoundState copyWith({bool? recording, bool? checking, int? tries, int? pct, String? msg}) =>
      SoundState(recording: recording ?? this.recording, checking: checking ?? this.checking, tries: tries ?? this.tries, pct: pct ?? this.pct, msg: msg ?? this.msg);
}

/// Sonido débil: decir la palabra hasta que el sonido salga bien (o 3 intentos).
class SoundController extends AutoDisposeFamilyNotifier<SoundState, SoundStep> {
  String get word => arg.word;
  String get phoneme => arg.phoneme;

  @override
  SoundState build(SoundStep step) => const SoundState();

  /// La técnica de este sonido, para mostrarla (o decirla) cuando no sale.
  List<WordTips> get tips => [if (tipFor(phoneme) != null) WordTips(word, [tipFor(phoneme)!])];

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
      if (!r.heard && !r.maybeVoice) {
        state = state.copyWith(recording: false, msg: tr('No te oí. Habla un poco más cerca.'));
      } else {
        // Ya no graba: ahora evalúa. Así la vista muestra "Evaluando…" y no el micro en rojo.
        state = state.copyWith(recording: false, checking: true);
        await _assess(r.wav);
        state = state.copyWith(checking: false);
        if (!state.finished) audio.say(word, slow: true);
      }
    } catch (e) {
      state = state.copyWith(recording: false, checking: false, msg: '$e');
    }
  }

  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    await hf.say(word, slow: true);
    while (!state.finished) {
      final h = await hf.listen(maxMs: 3500, silenceMs: 700, transcribe: false);
      if (h.silent) {
        await hf.say("I didn't hear you. Say $word.");
        continue;
      }
      await _assess(h.wav!);
      if (state.passed) {
        await hf.say('Great!');
      } else if (!state.finished) {
        await hf.say('Almost.');
        if (state.tries == 1) await sayTip(hf, tips, spanish: ref.read(spanishProvider).step <= 2);
        await hf.say('Listen again.');
        await hf.say(word, slow: true);
      } else {
        await hf.say("Let's keep practicing this one.");
      }
    }
    return state.outcome;
  }
}

final soundControllerProvider = NotifierProvider.autoDispose.family<SoundController, SoundState, SoundStep>(SoundController.new);
