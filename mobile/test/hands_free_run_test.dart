
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/services/audio_service.dart';
import 'package:word_to_word/core/services/hands_free.dart';

/// Audio de mentira: "habla" al instante.
class _FakeAudio extends AppAudio {
  _FakeAudio() : super(Api());
  final said = <String>[];
  @override
  Future<void> say(String text, {String lang = 'en', bool slow = false}) async => said.add(text);
  @override
  Future<void> stopVoice() async {}
  @override
  void stopRecording() {}

  /// Graba "silencio": no te oye.
  @override
  Future<Recording> record({int maxMs = 6000, int silenceMs = 1200, void Function()? onVoice}) async =>
      Recording(Uint8List(0), false, maxMs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Los plugins nativos (almacenamiento, grabadora, reproductor) no existen en los tests: se ignoran.
  for (final ch in ['plugins.it_nomads.com/flutter_secure_storage', 'com.llfbandit.record/messages', 'com.ryanheise.just_audio.methods']) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
  }

  test('manos libres: al salir de una pantalla su vuelta se corta y la nueva funciona', () async {
    final audio = _FakeAudio();
    final c = ProviderContainer(overrides: [audioProvider.overrideWithValue(audio)]);
    addTearDown(c.dispose);
    final hf = c.read(handsFreeProvider.notifier);
    await hf.setOn(true);

    final old = hf.begin();
    final now = hf.begin(); // volviste a entrar: empieza otra vuelta
    await expectLater(hf.runAs(old, () => hf.say('old')), throwsA(isA<HandsFreePaused>()));
    await hf.runAs(now, () => hf.say('new'));
    expect(audio.said, ['new']);

    hf.cancel(now); // saliste otra vez
    await expectLater(hf.runAs(now, () => hf.say('late')), throwsA(isA<HandsFreePaused>()));
    expect(c.read(handsFreeProvider).on, isTrue); // salir no apaga el manos libres
  });

  test('opción por número: "two", "number three", "the second one"; no dentro de frases', () {
    expect(parseOptionNumber('two', 3), 1);
    expect(parseOptionNumber('Number three.', 3), 2);
    expect(parseOptionNumber('the second one', 3), 1);
    expect(parseOptionNumber('one', 3), 0);
    expect(parseOptionNumber('I want to go for it', 3), -1);
    expect(parseOptionNumber('four', 3), -1); // solo hay 3 opciones
    // Azure devuelve dígitos: "2.", "Number 3".
    expect(parseOptionNumber('2.', 3), 1);
    expect(parseOptionNumber('Number 3', 3), 2);
    expect(parseOptionNumber('1', 3), 0);
  });

  test('manos libres: un error suelto del servidor se avisa y sigue; dos seguidos sí se lanzan', () async {
    final audio = _FakeAudio();
    final c = ProviderContainer(overrides: [audioProvider.overrideWithValue(audio)]);
    addTearDown(c.dispose);
    final hf = c.read(handsFreeProvider.notifier);
    await hf.setOn(true);

    // Un 500 suelto: lo dice y devuelve null (el ejercicio vuelve a escuchar).
    expect(await hf.server<bool>(() async => throw ApiException('Error del servidor', 500)), isNull);
    expect(audio.said, ['Sorry, something went wrong. Try again.']);
    // Si luego sale bien, el contador vuelve a cero...
    expect(await hf.server(() async => true), isTrue);
    expect(await hf.server<bool>(() async => throw ApiException('sin red')), isNull); // red caída (status 0)
    // ...y al segundo error seguido se lanza: el manos libres se pausará como antes.
    await expectLater(hf.server<bool>(() async => throw ApiException('Error del servidor', 503)), throwsA(isA<ApiException>()));
    expect(audio.said.length, 2);
  });

  test('manos libres: límite del día o sesión caducada no se reintentan', () async {
    final audio = _FakeAudio();
    final c = ProviderContainer(overrides: [audioProvider.overrideWithValue(audio)]);
    addTearDown(c.dispose);
    final hf = c.read(handsFreeProvider.notifier);
    await hf.setOn(true);

    for (final status in [401, 422, 429]) {
      await expectLater(hf.server<bool>(() async => throw ApiException('no', status)), throwsA(isA<ApiException>()));
    }
    expect(audio.said, isEmpty);
  });

  test('manos libres: si no te oye dos veces seguidas, se pausa (sin avanzar)', () async {
    final audio = _FakeAudio();
    final c = ProviderContainer(overrides: [audioProvider.overrideWithValue(audio)]);
    addTearDown(c.dispose);
    final hf = c.read(handsFreeProvider.notifier);
    await hf.setOn(true);

    final first = await hf.listen(transcribe: false);
    expect(first.silent, isTrue);
    expect(c.read(handsFreeProvider).on, isTrue);       // la primera vez solo vuelve a preguntar
    await expectLater(hf.listen(transcribe: false), throwsA(isA<HandsFreePaused>().having((p) => p.silence, 'silence', true)));
    expect(c.read(handsFreeProvider).on, isFalse);      // a la segunda, en pausa
  });
}
