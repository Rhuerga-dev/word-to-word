import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import '../utils/json.dart';
import 'audio_service.dart';
import '../../features/auth/presentation/auth_controller.dart';

/// Órdenes de voz del modo manos libres (en inglés a propósito).
enum VoiceCommand { repeat, slower, next, help, stop }

String _clean(String text) => text.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// La orden que hay en lo que dijiste, si es solo una orden (1–3 palabras).
VoiceCommand? parseCommand(String text) {
  final words = _clean(text).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty || words.length > 3) return null;
  final t = words.join(' ');
  if (RegExp(r'\b(repeat|say it again|one more time)\b').hasMatch(t)) return VoiceCommand.repeat;
  if (RegExp(r'\b(slower|slowly|slow down)\b').hasMatch(t)) return VoiceCommand.slower;
  if (RegExp(r'\b(next|skip)\b').hasMatch(t)) return VoiceCommand.next;
  if (RegExp(r'\b(help|hint)\b').hasMatch(t)) return VoiceCommand.help;
  if (RegExp(r'\b(stop|pause)\b').hasMatch(t)) return VoiceCommand.stop;
  return null;
}

/// La nota de una ficha dicha en voz alta: again · hard · good · easy (o null si no se entendió).
String? parseGrade(String text) {
  final t = _clean(text);
  if (RegExp(r'\b(again|forgot|no idea)\b').hasMatch(t)) return 'again';
  if (RegExp(r'\b(hard|difficult)\b').hasMatch(t)) return 'hard';
  if (RegExp(r'\b(easy)\b').hasMatch(t)) return 'easy';
  if (RegExp(r'\b(good|fine|ok|okay|got it)\b').hasMatch(t)) return 'good';
  return null;
}

enum HfPhase { idle, speaking, listening, thinking }

class HandsFreeState {
  const HandsFreeState({this.on = false, this.phase = HfPhase.idle, this.prompt = '', this.heard = ''});
  final bool on;
  final HfPhase phase;

  /// Lo último que dijo la app y lo último que se te entendió.
  final String prompt, heard;

  HandsFreeState copyWith({bool? on, HfPhase? phase, String? prompt, String? heard}) =>
      HandsFreeState(on: on ?? this.on, phase: phase ?? this.phase, prompt: prompt ?? this.prompt, heard: heard ?? this.heard);
}

/// Lo que se oyó: el texto y la orden de voz, si la hubo.
class Heard {
  const Heard(this.text, this.command, {this.wav, this.silent = false});
  final String text;
  final VoiceCommand? command;
  final Uint8List? wav;
  final bool silent;
}

/// Se lanza cuando pausas el manos libres en medio de un ejercicio ([silence]: se pausó solo porque no te oyó).
class HandsFreePaused implements Exception {
  HandsFreePaused({this.silence = false});
  final bool silence;
}

/// Manos libres: la app habla, te escucha y sigue sola. Los ejercicios lo usan para hacer su parte por voz.
class HandsFreeController extends Notifier<HandsFreeState> {
  static const _key = 'hands_free';
  final _storage = const FlutterSecureStorage();
  String _last = '';
  String _lastLang = 'en';

  /// Escuchas seguidas sin oírte. A la tercera se pausa: nunca se avanza ni se califica sin tu respuesta.
  int _silent = 0;
  static const maxSilent = 3;

  AppAudio get _audio => ref.read(audioProvider);

  @override
  HandsFreeState build() {
    _storage.read(key: _key).then((v) {
      if (v == '1') state = state.copyWith(on: true);
    }).catchError((_) {});
    return const HandsFreeState();
  }

  Future<void> setOn(bool on) async {
    state = state.copyWith(on: on, phase: HfPhase.idle);
    _silent = 0;
    if (!on) _interrupt();
    try {
      await _storage.write(key: _key, value: on ? '1' : '0');
    } catch (_) {}
  }

  void pause() => setOn(false);

  void _interrupt() {
    _audio.stopRecording();
    _audio.stopVoice();
  }

  void _check() {
    if (!state.on) throw HandsFreePaused();
  }

  /// La app dice [text] y espera a que termine.
  Future<void> say(String text, {String lang = 'en', bool slow = false}) async {
    _check();
    _last = text;
    _lastLang = lang;
    state = state.copyWith(phase: HfPhase.speaking, prompt: text);
    await _audio.say(text, lang: lang, slow: slow);
    _check();
  }

  Future<void> repeatLast({bool slow = false}) => say(_last, lang: _lastLang, slow: slow);

  /// Escucha hasta tu pausa. Con [transcribe] también lo pasa a texto y busca órdenes de voz.
  Future<Heard> listen({int maxMs = 6000, int silenceMs = 1200, bool transcribe = true}) async {
    _check();
    state = state.copyWith(phase: HfPhase.listening, heard: '');
    final r = await _audio.record(maxMs: maxMs, silenceMs: silenceMs);
    _check();
    if (!r.heard && !r.maybeVoice) return _nothing(r.wav);
    if (!transcribe) {
      if (r.heard) _silent = 0; // con voz baja, lo decide el servidor al evaluarlo
      state = state.copyWith(phase: HfPhase.thinking);
      return Heard('', null, wav: r.wav);
    }
    state = state.copyWith(phase: HfPhase.thinking);
    var text = '';
    try {
      text = asString(asMap(await ref.read(apiProvider).upload('/speech/transcribe', r.wav))['text']);
    } catch (_) {}
    _check();
    // Voz baja: solo cuenta si el servidor entendió algo; si no, era ruido.
    if (!r.heard && text.trim().isEmpty) return _nothing(r.wav);
    _silent = 0;
    state = state.copyWith(heard: text);
    return Heard(text, parseCommand(text), wav: r.wav);
  }

  /// No te oyó. A la tercera vez seguida se pausa (nunca se avanza ni se califica sin tu respuesta).
  Future<Heard> _nothing(Uint8List wav) async {
    state = state.copyWith(phase: HfPhase.idle);
    if (++_silent >= maxSilent) await _pauseForSilence();
    return Heard('', null, wav: wav, silent: true);
  }

  void idle() => state = state.copyWith(phase: HfPhase.idle);

  /// No te oye dos veces seguidas: lo dice y se queda en pausa en el mismo ejercicio.
  Future<void> _pauseForSilence() async {
    final spanish = ref.read(spanishProvider).step == 1;
    try {
      await say(spanish ? 'No te oigo. Lo dejo en pausa; actívalo cuando quieras seguir.' : "I can't hear you. I'll pause here. Turn it back on when you're ready.", lang: spanish ? 'es' : 'en');
    } on HandsFreePaused {
      // ya estaba en pausa
    }
    await setOn(false);
    throw HandsFreePaused(silence: true);
  }
}

final handsFreeProvider = NotifierProvider<HandsFreeController, HandsFreeState>(HandsFreeController.new);

/// Se lanza cuando dices "next": el ejercicio se salta.
class SkipExercise implements Exception {}

/// Atiende las órdenes generales. Devuelve true si había una orden (y ya se atendió): hay que volver a escuchar.
Future<bool> handleCommand(HandsFreeController hf, Heard h, {Future<void> Function()? onHelp}) async {
  switch (h.command) {
    case VoiceCommand.repeat:
      await hf.repeatLast();
      return true;
    case VoiceCommand.slower:
      await hf.repeatLast(slow: true);
      return true;
    case VoiceCommand.help:
      if (onHelp != null) {
        await onHelp();
      } else {
        await hf.say('Say repeat, slower, next or stop.');
      }
      return true;
    case VoiceCommand.stop:
      hf.pause();
      throw HandsFreePaused();
    case VoiceCommand.next:
      throw SkipExercise();
    case null:
      return false;
  }
}
