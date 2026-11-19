// Experimento A/B del Modo Brainy: el valor por defecto del servidor, la elección del alumno y lo que se informa.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/services/brainy_mode_setting.dart';
import 'package:word_to_word/features/auth/data/user_profile.dart';
import 'package:word_to_word/features/experiments/data/brainy_experiment.dart';

/// El ajuste con la «memoria del teléfono» en una variable (sin tocar el almacén seguro de verdad).
class _Phone extends BrainyModeSetting {
  _Phone(this.stored);
  String? stored;
  @override
  Future<String?> readStored() async => stored;
  @override
  Future<void> writeStored(String value) async => stored = value;
}

/// Servidor de mentira: apunta lo que recibe; con [status] distinto de 200 hace de servidor que falla.
class _Server implements HttpClientAdapter {
  _Server({this.status = 200});
  int status;
  final sent = <Map<String, dynamic>>[];
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    paths.add('${o.method} ${o.uri.path}');
    sent.add(Map<String, dynamic>.from(o.data as Map));
    return ResponseBody.fromString(jsonEncode({'ok': true}), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Api _api(_Server server) => Api(dio: Dio(BaseOptions(baseUrl: 'https://test/api'))..httpClientAdapter = server);

ProviderContainer _app({required bool? serverDefault, String? stored, _Server? server}) {
  final c = ProviderContainer(overrides: [
    brainyServerDefaultProvider.overrideWithValue(serverDefault),
    brainyModeProvider.overrideWith(() => _Phone(stored)),
    if (server != null) apiProvider.overrideWithValue(_api(server)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('Perfil', () {
    Map<String, dynamic> me([Object? value = #none]) => {
          'name': 'Ana',
          'cefr_level': 'A2',
          'reminder': <String, dynamic>{},
          'spanish': <String, dynamic>{},
          if (value != #none) 'brainy_default': value,
        };

    test('lee brainy_default del servidor', () {
      expect(UserProfile.fromJson(me(true)).brainyDefault, isTrue);
      expect(UserProfile.fromJson(me(false)).brainyDefault, isFalse);
    });

    test('servidor viejo, experimento apagado o un valor raro: null (la app sigue como siempre)', () {
      expect(UserProfile.fromJson(me()).brainyDefault, isNull);
      expect(UserProfile.fromJson(me(null)).brainyDefault, isNull);
      expect(UserProfile.fromJson(me('yes')).brainyDefault, isNull);
      expect(UserProfile.fromJson(me(1)).brainyDefault, isNull);
    });

    test('el valor se conserva al cambiar otra parte del perfil', () {
      expect(UserProfile.fromJson(me(true)).withSpanish(const SpanishInfo()).brainyDefault, isTrue);
    });
  });

  group('Ajuste', () {
    test('si nunca tocó el interruptor, manda el servidor', () async {
      final on = _app(serverDefault: true);
      expect(await on.read(brainyModeProvider.future), isTrue);
      expect(on.read(brainyModeProvider.notifier).changed, isFalse);

      final off = _app(serverDefault: false);
      expect(await off.read(brainyModeProvider.future), isFalse);
      expect(off.read(brainyModeProvider.notifier).changed, isFalse);
    });

    test('sin experimento nace apagado, como siempre', () async {
      final c = _app(serverDefault: null);
      expect(await c.read(brainyModeProvider.future), isFalse);
      expect(c.read(brainyModeProvider.notifier).changed, isFalse);
    });

    test('si lo tocó, su elección manda aunque el servidor proponga otra cosa', () async {
      final offByHand = _app(serverDefault: true, stored: '0');
      expect(await offByHand.read(brainyModeProvider.future), isFalse);
      expect(offByHand.read(brainyModeProvider.notifier).changed, isTrue);

      final onByHand = _app(serverDefault: false, stored: '1');
      expect(await onByHand.read(brainyModeProvider.future), isTrue);
      expect(onByHand.read(brainyModeProvider.notifier).changed, isTrue);

      final beforeTheExperiment = _app(serverDefault: null, stored: '1');
      expect(await beforeTheExperiment.read(brainyModeProvider.future), isTrue, reason: 'quien ya lo había encendido lo conserva');
    });

    test('al tocarlo se guarda y se recuerda que lo cambió', () async {
      final c = _app(serverDefault: true);
      await c.read(brainyModeProvider.future);
      final setting = c.read(brainyModeProvider.notifier) as _Phone;

      await setting.set(false);
      expect(c.read(brainyModeProvider).value, isFalse);
      expect(setting.changed, isTrue);
      expect(setting.stored, '0');

      // Al volver a calcularse (p. ej. llega otra vez el perfil), sigue mandando su elección.
      c.invalidate(brainyModeProvider);
      expect(await c.read(brainyModeProvider.future), isFalse);
      expect(c.read(brainyModeProvider.notifier).changed, isTrue);
    });
  });

  group('Informar al servidor', () {
    test('sin experimento no se envía nada', () async {
      final server = _Server();
      final c = _app(serverDefault: null, server: server);
      await c.read(brainyModeProvider.future);
      c.read(brainyExperimentReporterProvider);
      await _settle();
      expect(server.sent, isEmpty);
    });

    test('informa del modo real al entrar y otra vez cuando el alumno lo cambia', () async {
      final server = _Server();
      final c = _app(serverDefault: true, server: server);
      c.listen(brainyExperimentReporterProvider, (_, __) {});
      await c.read(brainyModeProvider.future);
      await _settle();

      expect(server.paths, ['POST /api/experiments/brainy']);
      expect(server.sent.single, {'mode': true, 'changed': false});

      await c.read(brainyModeProvider.notifier).set(false);
      await _settle();
      expect(server.sent.length, 2);
      expect(server.sent.last, {'mode': false, 'changed': true});
      expect(server.sent.last.containsKey('user_id'), isFalse);
      expect(server.sent.last.containsKey('group'), isFalse, reason: 'el grupo lo decide el servidor');
    });

    test('no repite lo mismo dos veces', () async {
      final server = _Server();
      final repo = BrainyExperimentRepository(_api(server));
      await repo.report(mode: true, changed: false);
      await repo.report(mode: true, changed: false);
      expect(server.sent.length, 1);
      await repo.report(mode: true, changed: true);
      expect(server.sent.length, 2);
    });

    test('si el servidor falla no pasa nada, y se reintenta la próxima vez', () async {
      final server = _Server(status: 500);
      final repo = BrainyExperimentRepository(_api(server));
      await repo.report(mode: true, changed: false); // no lanza
      await repo.opened(mode: true, changed: false); // no lanza
      server.status = 200;
      await repo.report(mode: true, changed: false);
      expect(server.sent.length, 3, reason: 'lo que falló no se da por enviado');
    });

    testWidgets('abrir la pantalla de Brainy se cuenta una vez', (tester) async {
      final server = _Server();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          brainyServerDefaultProvider.overrideWithValue(false),
          brainyModeProvider.overrideWith(() => _Phone('1')),
          apiProvider.overrideWithValue(_api(server)),
        ],
        child: const MaterialApp(home: _Screen()),
      ));
      await _run(tester);

      expect(server.sent.where((b) => b['opened'] == true).toList(), [
        {'mode': true, 'changed': true, 'opened': true},
      ]);
    });

    testWidgets('sin experimento, abrir Brainy no envía nada', (tester) async {
      final server = _Server();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          brainyServerDefaultProvider.overrideWithValue(null),
          brainyModeProvider.overrideWith(() => _Phone(null)),
          apiProvider.overrideWithValue(_api(server)),
        ],
        child: const MaterialApp(home: _Screen()),
      ));
      await _run(tester);
      expect(server.sent, isEmpty);
    });
  });
}

/// Deja pasar unos cuadros y un poco de tiempo real, para que la petición de mentira termine.
Future<void> _run(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(_settle);
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Una pantalla que espera a que el ajuste esté leído y entonces enseña «Brainy» (como hace la app).
class _Screen extends ConsumerWidget {
  const _Screen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(brainyModeProvider).hasValue;
    return ready ? const BrainyOpened(child: Text('Brainy')) : const SizedBox();
  }
}
