import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../data/ear_item.dart';
import '../../data/session_repository.dart';
import 'exercise_outcome.dart';

class EarState {
  const EarState({this.playing = true, this.endedAt, this.chosen, this.ms = 0, this.result, this.error, this.lens = false, this.look});
  final bool playing;

  /// Cuándo terminó de sonar (desde ahí se cuenta lo que tardas).
  final DateTime? endedAt;
  final int? chosen;
  final int ms;
  final EarResult? result;
  final String? error;

  /// Modo lupa: tocar las palabras de las opciones para entenderlas.
  final bool lens;

  /// Lo último que buscaste con la lupa.
  final String? look;

  bool get answered => chosen != null;
  bool get finished => result != null || error != null;

  EarState copyWith({bool? playing, DateTime? endedAt, int? chosen, int? ms, EarResult? result, String? error, bool? lens, String? look}) => EarState(
      playing: playing ?? this.playing,
      endedAt: endedAt ?? this.endedAt,
      chosen: chosen ?? this.chosen,
      ms: ms ?? this.ms,
      result: result ?? this.result,
      error: error ?? this.error,
      lens: lens ?? this.lens,
      look: look ?? this.look);
}

/// Oído por escalones: sonido → significado fácil → definición → en una frase → rápido.
class EarController extends AutoDisposeFamilyNotifier<EarState, EarItem> {
  EarItem get item => arg;

  @override
  EarState build(EarItem item) => const EarState();

  ExerciseOutcome outcome() => ExerciseOutcome(xp: state.result?.xp ?? 0, graded: true, ok: state.chosen == item.answer);

  bool get fast => state.chosen == item.answer && state.ms <= item.fastMs;

  /// Suena lo de este escalón (la palabra, despacio al principio, o la frase y la palabra).
  Future<void> play() async {
    state = state.copyWith(playing: true);
    final audio = ref.read(audioProvider);
    final parts = item.sounds;
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 450));
      await audio.say(parts[i].text, slow: parts[i].slow);
    }
    // Solo la primera vez empieza a contar el tiempo.
    state = state.copyWith(playing: false, endedAt: state.endedAt ?? DateTime.now());
  }

  void toggleLens() => state = state.copyWith(lens: !state.lens);

  /// Toca una palabra que no entiendes: la dice y muestra su significado más simple.
  Future<void> lookUp(String word) async {
    state = state.copyWith(look: '$word…');
    ref.read(audioProvider).say(word);
    try {
      final r = await ref.read(sessionRepositoryProvider).lookup(word);
      state = state.copyWith(look: '${r.word} = ${r.text}');
    } catch (e) {
      state = state.copyWith(look: '$word: $e');
    }
  }

  Future<void> choose(int i) async {
    if (state.answered || state.endedAt == null || state.lens) return;
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

  static String _plain(String t) => t.replaceAll(RegExp(r'[^\x00-\x7F]'), '').trim();
  static String _norm(String t) => t.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Manos libres. Escalón "sonido": repites la palabra que oíste y se compara con las opciones.
  /// Los demás: dices qué significa (en inglés), te dice la respuesta y le dices si la sabías.
  /// El tiempo va desde que termina de sonar hasta que empiezas a hablar.
  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    if (state.finished) return outcome();
    Future<void> sayItem() async {
      for (final a in item.sounds) {
        await hf.say(a.text, slow: a.slow);
      }
    }

    await hf.say('Listen.');
    await sayItem();
    final t0 = DateTime.now();
    DateTime? voice;

    if (item.mode == 'sound') {
      await hf.say('Which word did you hear? Say it.');
      while (true) {
        final h = await hf.listen(maxMs: 5000, onVoice: () => voice ??= DateTime.now());
        if (h.silent) {
          await sayItem();
          continue;
        }
        if (await handleCommand(hf, h, onHelp: sayItem)) continue;
        final heard = ' ${_norm(h.text)} ';
        final said = item.options.indexWhere((o) => heard.contains(' ${o.toLowerCase()} '));
        if (said < 0) {
          await hf.say('Say it again: which word did you hear?');
          continue;
        }
        final ms = (voice ?? DateTime.now()).difference(t0).inMilliseconds;
        await _send(said == item.answer, ms, chosen: said);
        await hf.say(said == item.answer ? 'Yes! ${item.word}.' : 'It was ${item.word}.');
        return outcome();
      }
    }

    while (true) {
      final h = await hf.listen(maxMs: 6000, onVoice: () => voice ??= DateTime.now());
      if (h.silent) {
        await hf.say('What does it mean? Say it in English.');
        await sayItem();
        continue;
      }
      if (!await handleCommand(hf, h, onHelp: () => hf.say(item.example ?? item.word))) break;
    }
    final ms = (voice ?? DateTime.now()).difference(t0).inMilliseconds;
    await hf.say('It means: ${_plain(item.meaning)}. Did you know it? Yes or no.');
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
