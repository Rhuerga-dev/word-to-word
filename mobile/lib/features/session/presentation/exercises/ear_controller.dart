import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../../../core/utils/compare.dart';
import '../../../../core/utils/pron_tips.dart';
import '../../../../core/widgets/how_to_say.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/ear_item.dart';
import '../../data/session_repository.dart';
import 'exercise_outcome.dart';

class EarState {
  const EarState({
    this.playing = true,
    this.endedAt,
    this.chosen,
    this.ms = 0,
    this.result,
    this.error,
    this.recording = false,
    this.checking = false,
    this.tries = 0,
    this.match,
    this.heard = '',
    this.msg = '',
    this.tips = const [],
    this.loadingTips = false,
  });
  final bool playing;

  /// Cuándo terminó de sonar (desde ahí se cuenta lo que tardas).
  final DateTime? endedAt;
  final int? chosen;
  final int ms;
  final EarResult? result;
  final String? error;

  // Escalones de repetir.
  final bool recording, checking;
  final int tries;
  final WordMatch? match;
  final String heard, msg;

  /// Cuando no se te entendió: cómo decir las palabras que fallaron.
  final List<WordTips> tips;
  final bool loadingTips;

  bool get answered => chosen != null;
  bool get finished => result != null || error != null;

  EarState copyWith({
    bool? playing,
    DateTime? endedAt,
    int? chosen,
    int? ms,
    EarResult? result,
    String? error,
    bool? recording,
    bool? checking,
    int? tries,
    WordMatch? match,
    String? heard,
    String? msg,
    List<WordTips>? tips,
    bool? loadingTips,
  }) =>
      EarState(
        playing: playing ?? this.playing,
        endedAt: endedAt ?? this.endedAt,
        chosen: chosen ?? this.chosen,
        ms: ms ?? this.ms,
        result: result ?? this.result,
        error: error ?? this.error,
        recording: recording ?? this.recording,
        checking: checking ?? this.checking,
        tries: tries ?? this.tries,
        match: match ?? this.match,
        heard: heard ?? this.heard,
        msg: msg ?? this.msg,
        tips: tips ?? this.tips,
        loadingTips: loadingTips ?? this.loadingTips,
      );
}

/// Oído por escalones: primero escuchar y tocar; después escuchar y repetir, cada vez algo más largo.
class EarController extends AutoDisposeFamilyNotifier<EarState, EarItem> {
  EarItem get item => arg;

  /// Intentos para repetir antes de dejarlo para mañana.
  static const maxTries = 2;

  @override
  EarState build(EarItem item) => const EarState();

  bool get passed => item.isRepeat ? (state.match?.pct ?? 0) >= item.pass : state.chosen == item.answer;

  ExerciseOutcome outcome() => ExerciseOutcome(xp: state.result?.xp ?? 0, graded: true, ok: passed);

  bool get fast => passed && state.ms <= item.fastMs;

  /// Suena lo de este escalón.
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

  /// Escalones de tocar.
  Future<void> choose(int i) async {
    if (state.answered || state.endedAt == null) return;
    final ms = DateTime.now().difference(state.endedAt!).inMilliseconds;
    await _send(i == item.answer, ms, chosen: i);
  }

  /// Escalones de repetir: grabas, se pasa a texto y se compara palabra por palabra.
  Future<void> attempt() async {
    if (state.finished || state.recording || state.checking) return;
    final audio = ref.read(audioProvider);
    final target = item.target ?? item.word;
    final t0 = state.endedAt ?? DateTime.now();
    DateTime? voice;
    state = state.copyWith(recording: true, msg: '');
    try {
      final words = target.split(' ').length;
      final rec = await audio.record(maxMs: 4000 + words * 700, silenceMs: 1200, onVoice: () => voice ??= DateTime.now());
      state = state.copyWith(recording: false);
      if (!rec.heard && !rec.maybeVoice) {
        state = state.copyWith(msg: tr('No te oí. Habla un poco más cerca.'));
        return;
      }
      state = state.copyWith(checking: true);
      final text = await ref.read(sessionRepositoryProvider).transcribe(rec.wav);
      await _judge(text, (voice ?? DateTime.now()).difference(t0).inMilliseconds);
      if (!passed) await _loadTips(rec.wav);
    } catch (e) {
      state = state.copyWith(recording: false, msg: '$e');
    } finally {
      if (state.checking) state = state.copyWith(checking: false);
    }
  }

  /// Compara lo que se entendió; pasa con [EarItem.pass] % o falla al segundo intento.
  Future<bool> _judge(String heard, int ms) async {
    final m = matchWords(item.target ?? item.word, heard);
    final tries = state.tries + 1;
    state = state.copyWith(match: m, heard: heard, tries: tries, checking: false);
    final ok = m.pct >= item.pass;
    if (ok || tries >= maxTries) {
      await _send(ok, ms, chosen: ok ? 0 : 1);
      return true;
    }
    return false;
  }

  /// No se te entendió: qué sonidos fallaron (Azure) y la técnica para cada uno. Sin detalle, por la ortografía.
  Future<void> _loadTips(Uint8List wav) async {
    final target = item.target ?? item.word;
    final missed = [for (final (w, ok) in state.match?.tokens ?? const <(String, bool)>[]) if (!ok) w];
    state = state.copyWith(loadingTips: true);
    var weak = <(String, List<String>)>[];
    try {
      weak = await ref.read(sessionRepositoryProvider).pronTips(target, wav).timeout(const Duration(seconds: 10));
    } catch (_) {}
    if (weak.isEmpty) weak = [for (final w in missed.isEmpty ? target.split(' ') : missed) (w, const <String>[])];
    state = state.copyWith(tips: buildTips(weak), loadingTips: false);
  }

  Future<void> _send(bool ok, int ms, {required int chosen}) async {
    state = state.copyWith(chosen: chosen, ms: ms);
    try {
      state = state.copyWith(result: await ref.read(sessionRepositoryProvider).ear(item.id, ok: ok, ms: ms));
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  static const _numbers = ['one', 'two', 'three', 'four', 'five', 'six'];

  static String _plain(String t) => t.replaceAll(RegExp(r'[^\x00-\x7F]'), '').trim();
  static String _norm(String t) => t.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Manos libres: sonido → repites la palabra y se compara con las opciones; significado → dices qué
  /// significa y luego si la sabías; repetir → repites lo que oíste (dos intentos).
  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    if (state.finished) return outcome();
    Future<void> sayItem() async {
      for (final a in item.sounds) {
        await hf.say(a.text, slow: a.slow);
      }
    }

    await hf.say(item.isRepeat ? 'Listen and repeat.' : 'Listen.');
    await sayItem();
    var t0 = DateTime.now();
    DateTime? voice;

    if (item.isRepeat) {
      while (true) {
        voice = null;
        final h = await hf.listen(maxMs: 4000 + (item.target ?? '').split(' ').length * 700, onVoice: () => voice ??= DateTime.now());
        if (h.silent) {
          await hf.say('Repeat after me.');
          await sayItem();
          t0 = DateTime.now();
          continue;
        }
        if (await handleCommand(hf, h, onHelp: () async {
          await hf.say(item.target ?? item.word, slow: true);
        })) {
          continue;
        }
        final done = await _judge(h.text, (voice ?? DateTime.now()).difference(t0).inMilliseconds);
        if (passed) {
          await hf.say(state.match!.pct >= 100 ? 'Perfect!' : 'Good!');
          return outcome();
        }
        if (h.wav != null) await _loadTips(h.wav!);
        if (done) {
          await sayTip(hf, state.tips, spanish: ref.read(spanishProvider).step <= 2);
          await hf.say("Let's practice it again tomorrow.");
          return outcome();
        }
        await hf.say('Almost.');
        await sayTip(hf, state.tips, spanish: ref.read(spanishProvider).step <= 2);
        await hf.say('Listen slowly, then say it.');
        await hf.say(item.target ?? item.word, slow: true);
        await sayItem();
        t0 = DateTime.now();
      }
    }

    if (item.mode == 'sound') {
      await hf.say('Which word did you hear? Say it.');
      var misses = 0;
      while (true) {
        final h = await hf.listen(maxMs: 5000, onVoice: () => voice ??= DateTime.now());
        if (h.silent) {
          await sayItem();
          continue;
        }
        if (await handleCommand(hf, h, onHelp: sayItem)) continue;
        final heard = ' ${_norm(h.text)} ';
        var said = item.options.indexWhere((o) => heard.contains(' ${o.toLowerCase()} '));
        // También vale decir el número de la opción ("one", "the second"…): se entiende mucho mejor.
        if (said < 0) said = parseOptionNumber(heard, item.options.length);
        if (said < 0) {
          misses++;
          if (misses == 1) {
            await hf.say("I didn't catch it. Say the word slowly and clearly, or say its number.");
          } else {
            // Las opciones en voz alta con su número, para que puedas elegir sin que dependa de tu pronunciación.
            final opts = [for (var i = 0; i < item.options.length; i++) '${_numbers[i]}: ${item.options[i]}'].join('. ');
            await hf.say('Your options. $opts. Say the number.');
          }
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
