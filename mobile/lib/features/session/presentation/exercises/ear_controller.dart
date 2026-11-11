import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../data/ear_item.dart';
import '../../data/session_repository.dart';
import 'exercise_outcome.dart';

/// Rápido = la reconoces sin traducir.
const earFastMs = 3000;

class EarState {
  const EarState({this.playing = true, this.endedAt, this.chosen, this.ms = 0, this.result, this.error});
  final bool playing;

  /// Cuándo terminó de sonar (desde ahí se cuenta lo que tardas).
  final DateTime? endedAt;
  final int? chosen;
  final int ms;
  final EarResult? result;
  final String? error;

  bool get answered => chosen != null;
  bool get finished => result != null || error != null;

  EarState copyWith({bool? playing, DateTime? endedAt, int? chosen, int? ms, EarResult? result, String? error}) =>
      EarState(playing: playing ?? this.playing, endedAt: endedAt ?? this.endedAt, chosen: chosen ?? this.chosen, ms: ms ?? this.ms, result: result ?? this.result, error: error ?? this.error);
}

/// Oído: suena la palabra (sin texto) y eliges qué significa, rápido.
class EarController extends AutoDisposeFamilyNotifier<EarState, EarItem> {
  EarItem get item => arg;

  @override
  EarState build(EarItem item) => const EarState();

  ExerciseOutcome outcome() => ExerciseOutcome(xp: state.result?.xp ?? 0, graded: true, ok: state.chosen == item.answer);

  /// Suena la palabra; el tiempo empieza a contar al terminar.
  Future<void> play() async {
    state = state.copyWith(playing: true);
    await ref.read(audioProvider).say(item.word);
    state = EarState(playing: false, endedAt: DateTime.now(), chosen: state.chosen, ms: state.ms, result: state.result, error: state.error);
  }

  Future<void> choose(int i) async {
    if (state.answered || state.endedAt == null) return;
    final ms = DateTime.now().difference(state.endedAt!).inMilliseconds;
    await _send(i == item.answer, ms, chosen: i);
  }

  Future<void> _send(bool ok, int ms, {required int chosen}) async {
    state = state.copyWith(chosen: chosen, ms: ms);
    try {
      state = state.copyWith(result: await ref.read(sessionRepositoryProvider).ear(item.id, ok: ok, ms: ms));
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  /// Manos libres: la app dice la palabra, tú dices qué significa (en inglés), te dice la respuesta
  /// y le dices si la sabías. Lo que tardas se mide desde que terminó la palabra hasta que empiezas a hablar.
  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    if (state.finished) return outcome();
    await hf.say('Listen.');
    await hf.say(item.word);
    final t0 = DateTime.now();
    DateTime? voice;
    while (true) {
      final h = await hf.listen(maxMs: 6000, onVoice: () => voice ??= DateTime.now());
      if (h.silent) {
        await hf.say('What does it mean? Say it in English.');
        await hf.say(item.word);
        continue;
      }
      if (!await handleCommand(hf, h, onHelp: () => hf.say(item.example ?? item.word))) break;
    }
    final ms = (voice ?? DateTime.now()).difference(t0).inMilliseconds;
    await hf.say('It means: ${item.meaning}. Did you know it? Yes or no.');
    while (true) {
      final h = await hf.listen(maxMs: 4000, silenceMs: 900);
      if (h.silent || await handleCommand(hf, h)) continue;
      final t = h.text.toLowerCase();
      final yes = RegExp(r'\b(yes|yeah|yep|sure|i did|right|correct|s[ií])\b').hasMatch(t);
      final no = RegExp(r"\b(no|nope|didn't|did not|wrong)\b").hasMatch(t);
      if (yes == no) {
        await hf.say('Say yes or no.');
        continue;
      }
      await _send(yes, ms, chosen: yes ? item.answer : (item.answer + 1) % item.options.length);
      final r = state.result;
      if (yes && r != null && r.fast) await hf.say(r.automatic ? 'Automatic! Great.' : 'Fast. Good.');
      return outcome();
    }
  }
}

final earControllerProvider = NotifierProvider.autoDispose.family<EarController, EarState, EarItem>(EarController.new);
