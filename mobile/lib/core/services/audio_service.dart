import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import '../../core/l10n/tr.dart';

/// Audio de la app: la voz natural (TTS del servidor) y el micrófono.
///
/// En el iPhone se usa la categoría "play and record". Con «Micrófono de los AirPods» (por defecto) se permite
/// el Bluetooth de llamada (HFP): se graba con los AirPods aunque el iPhone esté en el bolsillo, y la voz suena
/// con calidad de llamada. Apagado: voz en alta calidad (A2DP) y se graba con el micrófono del iPhone.
/// Solo esta clase configura el audio de iOS: la librería de grabación no lo toca (antes lo cambiaba al grabar
/// y el iPhone saltaba de modo entre hablar y escuchar).
/// En Android igual: la grabación NO activa el Bluetooth de llamada (SCO). Si lo activara, los auriculares
/// pasarían a modo llamada: baja el volumen y la calidad, y los AirPods quitan la cancelación de ruido.
class AppAudio {
  AppAudio(this.api);

  final Api api;
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _rec = AudioRecorder();
  final Map<String, String> _cache = {};
  bool _configured = false;
  Completer<void>? _stopRec;

  static const _micKey = 'airpods_mic';
  final _storage = const FlutterSecureStorage();
  bool? _airPodsMic;

  /// ¿Grabar con el micrófono de los AirPods? (solo iPhone; por defecto sí).
  Future<bool> airPodsMic() async {
    if (!Platform.isIOS) return false;
    if (_airPodsMic == null) {
      try {
        _airPodsMic = (await _storage.read(key: _micKey)) != '0';
      } catch (_) {
        _airPodsMic = true;
      }
    }
    return _airPodsMic!;
  }

  Future<void> setAirPodsMic(bool on) async {
    _airPodsMic = on;
    try {
      await _storage.write(key: _micKey, value: on ? '1' : '0');
    } catch (_) {}
    _configured = false;
    await _configure();
  }

  Future<void> _configure() async {
    if (_configured) return;
    final session = await AudioSession.instance;
    var options = AVAudioSessionCategoryOptions.allowBluetoothA2dp | AVAudioSessionCategoryOptions.defaultToSpeaker;
    if (Platform.isIOS) {
      // La app manda en la sesión de audio; la grabadora no la cambia al empezar a grabar.
      try {
        await _rec.ios?.manageAudioSession(false);
      } catch (_) {}
      if (await airPodsMic()) options = options | AVAudioSessionCategoryOptions.allowBluetooth;
    }
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: options,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
      ),
    ));
    if (Platform.isIOS) {
      try {
        await session.setActive(true);
      } catch (_) {}
    }
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
    if (!await _rec.hasPermission()) throw ApiException(tr('Permite el micrófono en Ajustes para hablar con la app.'));
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voz_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
        // Micrófono del teléfono; los auriculares siguen en modo música (A2DP) para oír la voz.
        androidConfig: AndroidRecordConfig(manageBluetooth: false),
      ),
      path: path,
    );
    final started = DateTime.now();
    var heard = false;
    var silentSince = DateTime.now();
    final floor = <double>[];
    var threshold = -40.0;
    var peak = -160.0;
    final done = _stopRec = Completer<void>();
    final sub = _rec.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
      final db = a.current;
      if (db > peak) peak = db;
      // Umbral según el ruido de fondo de los primeros ~0,4 s (el más bajo, por si ya empezaste a hablar).
      // Más sensible que antes: con la reducción de ruido de Android la voz llega bastante baja.
      if (floor.length < 3 && !heard) {
        floor.add(db);
        if (floor.length == 3) threshold = (floor.reduce((x, y) => x < y ? x : y) + 10).clamp(-52.0, -34.0);
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
    final floorDb = floor.isEmpty ? -160.0 : floor.reduce((x, y) => x < y ? x : y);
    return Recording(bytes, heard, DateTime.now().difference(started).inMilliseconds, peakDb: peak, floorDb: floorDb);
  }

  /// "Ya terminé": corta la grabación sin esperar el silencio.
  void stopRecording() {
    final c = _stopRec;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Los auriculares conectados (Bluetooth o con cable), o null si la voz sale por el altavoz.
  Future<String?> headphones() async {
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices(includeInputs: false);
      for (final d in devices) {
        final t = d.type.name.toLowerCase();
        if (t.contains('bluetooth') || t.contains('ble') || t.contains('wired') || t.contains('headset') || t.contains('headphone') || t.contains('hearing')) {
          final name = d.name.trim();
          return name.isEmpty ? tr('Auriculares') : name;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Avisa cuando conectas o desconectas unos auriculares.
  Stream<void> devicesChanged() async* {
    final session = await AudioSession.instance;
    yield* session.devicesChangedEventStream.map((_) {});
  }

  void dispose() {
    _player.dispose();
    _rec.dispose();
  }
}

class Recording {
  Recording(this.wav, this.heard, this.ms, {this.peakDb = -160, this.floorDb = -160});
  final Uint8List wav;
  final bool heard;
  final int ms;

  /// Lo más fuerte que se oyó y el ruido de fondo (dB). Sirve para no dar por "silencio" una voz baja.
  final double peakDb, floorDb;

  /// Hubo algo por encima del ruido aunque no llegara al umbral: puede ser tu voz, hablando bajo.
  bool get maybeVoice => !heard && peakDb > floorDb + 6 && peakDb > -55;
}

/// Interruptor «Micrófono de los AirPods» de Ajustes (solo iPhone).
class AirPodsMicNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(audioProvider).airPodsMic();

  Future<void> set(bool on) async {
    state = AsyncData(on);
    await ref.read(audioProvider).setAirPodsMic(on);
  }
}

final airPodsMicProvider = AsyncNotifierProvider<AirPodsMicNotifier, bool>(AirPodsMicNotifier.new);

final audioProvider = Provider<AppAudio>((ref) {
  final audio = AppAudio(ref.watch(apiProvider));
  ref.onDispose(audio.dispose);
  return audio;
});

/// Los auriculares conectados ahora mismo (null: altavoz del teléfono). Se actualiza al conectar o desconectar.
final headphonesProvider = StreamProvider<String?>((ref) async* {
  final audio = ref.watch(audioProvider);
  yield await audio.headphones();
  await for (final _ in audio.devicesChanged()) {
    yield await audio.headphones();
  }
});
