import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api.dart';

/// Audio de la app: la voz natural (TTS del servidor) y el micrófono.
///
/// En el iPhone se usa la categoría "play and record" permitiendo Bluetooth A2DP: con AirPods puestos, la voz sale
/// por los AirPods en alta calidad y se graba con el micrófono del iPhone (sin pasar a "modo llamada").
class AppAudio {
  AppAudio(this.api);

  final Api api;
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _rec = AudioRecorder();
  final Map<String, String> _cache = {};
  bool _configured = false;
  Completer<void>? _stopRec;

  Future<void> _configure() async {
    if (_configured) return;
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetoothA2dp | AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
      ),
    ));
    _configured = true;
  }

  /// Dice un texto con la voz natural y espera a que termine.
  Future<void> say(String text, {String lang = 'en', bool slow = false}) async {
    if (text.trim().isEmpty) return;
    await _configure();
    try {
      final key = '$lang|$slow|$text';
      var path = _cache[key];
      if (path == null || !File(path).existsSync()) {
        final bytes = await api.tts(text, lang: lang, slow: slow);
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/tts_${key.hashCode.toUnsigned(32)}.mp3';
        await File(path).writeAsBytes(bytes);
        _cache[key] = path;
      }
      await _player.setFilePath(path);
      await _player.play();
      await _player.processingStateStream.firstWhere((s) => s == ProcessingState.completed).timeout(
            Duration(seconds: 6 + text.length ~/ 8),
            onTimeout: () => ProcessingState.completed,
          );
      await _player.stop();
    } catch (_) {
      // Sin voz no se rompe el ejercicio: el texto sigue en pantalla.
    }
  }

  Future<void> stopVoice() => _player.stop();

  Future<bool> hasPermission() => _rec.hasPermission();

  /// Graba hasta [maxMs] o hasta [silenceMs] de silencio después de hablar.
  /// Devuelve el WAV (16 kHz mono) y si se oyó voz. [onVoice] avisa cuando empiezas a hablar.
  Future<Recording> record({int maxMs = 6000, int silenceMs = 1200, void Function()? onVoice}) async {
    await _configure();
    if (!await _rec.hasPermission()) throw ApiException('Permite el micrófono en Ajustes para hablar con la app.');
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voz_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rec.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1, autoGain: true, echoCancel: true, noiseSuppress: true),
      path: path,
    );
    final started = DateTime.now();
    var heard = false;
    var silentSince = DateTime.now();
    final floor = <double>[];
    var threshold = -38.0;
    final done = _stopRec = Completer<void>();
    final sub = _rec.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
      final db = a.current;
      // Umbral según el ruido de fondo de los primeros ~0,4 s.
      if (floor.length < 3 && !heard) {
        floor.add(db);
        if (floor.length == 3) threshold = (floor.reduce((x, y) => x < y ? x : y) + 14).clamp(-50.0, -28.0);
      }
      if (db > threshold) {
        if (!heard) onVoice?.call();
        heard = true;
        silentSince = DateTime.now();
      } else if (heard && DateTime.now().difference(silentSince).inMilliseconds > silenceMs) {
        if (!done.isCompleted) done.complete();
      }
    });
    await Future.any([done.future, Future.delayed(Duration(milliseconds: maxMs))]);
    await sub.cancel();
    final out = await _rec.stop();
    _stopRec = null;
    final file = File(out ?? path);
    final bytes = file.existsSync() ? await file.readAsBytes() : Uint8List(0);
    if (file.existsSync()) await file.delete();
    return Recording(bytes, heard, DateTime.now().difference(started).inMilliseconds);
  }

  /// "Ya terminé": corta la grabación sin esperar el silencio.
  void stopRecording() {
    final c = _stopRec;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _rec.dispose();
  }
}

class Recording {
  Recording(this.wav, this.heard, this.ms);
  final Uint8List wav;
  final bool heard;
  final int ms;
}
