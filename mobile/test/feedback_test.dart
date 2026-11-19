// Sugerencias: qué se envía al servidor y cómo se comporta el diálogo. Sin red (adaptador falso).
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/config/env.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/features/feedback/data/feedback_repository.dart';
import 'package:word_to_word/features/feedback/presentation/suggestion_dialog.dart';

/// Servidor de mentira: apunta lo que recibe y responde lo que se le diga.
class _Server implements HttpClientAdapter {
  _Server({this.status = 201, this.reply = const {'ok': true}});
  final int status;
  final Map<String, dynamic> reply;
  final sent = <Map<String, dynamic>>[];
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    paths.add('${o.method} ${o.uri.path}');
    sent.add(Map<String, dynamic>.from(o.data as Map));
    return ResponseBody.fromString(jsonEncode(reply), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Api _api(_Server server) => Api(dio: Dio(BaseOptions(baseUrl: 'https://test/api'))..httpClientAdapter = server);

Future<void> _open(WidgetTester tester, _Server server) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [feedbackRepositoryProvider.overrideWithValue(FeedbackRepository(_api(server), platform: 'android'))],
    child: const MaterialApp(home: Scaffold(body: SuggestionDialog(screen: 'settings'))),
  ));
}

void main() {
  test('la versión de la app es la de pubspec.yaml', () {
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(appVersion, version, reason: 'al subir la versión en pubspec.yaml, súbela también en lib/core/config/env.dart');
  });

  test('envía el tipo, el texto y, sola, la versión, la plataforma y la pantalla', () async {
    final server = _Server();
    await FeedbackRepository(_api(server), platform: 'ios').send(type: SuggestionType.bug, message: '  No suena el audio.  ', screen: 'settings');

    expect(server.paths, ['POST /api/suggestions']);
    expect(server.sent.single, {
      'type': 'bug',
      'message': 'No suena el audio.',
      'app_version': appVersion,
      'platform': 'ios',
      'screen': 'settings',
    });
    expect(server.sent.single.containsKey('user_id'), isFalse, reason: 'quién la envía lo sabe el servidor por la sesión');
  });

  test('los tipos son la lista fija del servidor', () {
    expect([for (final t in SuggestionType.values) t.name], ['idea', 'bug', 'other']);
  });

  testWidgets('con muy poco texto no envía nada y lo dice', (tester) async {
    final server = _Server();
    await _open(tester, server);
    await tester.enterText(find.byKey(const ValueKey('suggestion-text')), 'hola');
    await tester.tap(find.byKey(const ValueKey('suggestion-send')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un poco más.'), findsOneWidget);
    expect(server.sent, isEmpty);
  });

  testWidgets('envía la sugerencia y da las gracias', (tester) async {
    final server = _Server();
    await _open(tester, server);
    expect(find.text('💡 Enviar sugerencia'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('suggestion-text')), 'Me gustaría un modo oscuro.');
    await tester.tap(find.byKey(const ValueKey('suggestion-send')));
    await tester.pumpAndSettle();

    expect(server.sent.single['type'], 'idea');
    expect(server.sent.single['message'], 'Me gustaría un modo oscuro.');
    expect(server.sent.single['platform'], 'android');
    expect(find.text('¡Gracias!'), findsOneWidget);
    expect(find.byKey(const ValueKey('suggestion-text')), findsNothing);
  });

  testWidgets('si el servidor dice que no, enseña su mensaje y deja el texto para reintentar', (tester) async {
    final server = _Server(status: 429, reply: const {'message': 'Ya enviaste muchas sugerencias hoy. Mañana puedes enviar más.'});
    await _open(tester, server);
    await tester.enterText(find.byKey(const ValueKey('suggestion-text')), 'Otra idea más para la app.');
    await tester.tap(find.byKey(const ValueKey('suggestion-send')));
    await tester.pumpAndSettle();

    expect(find.text('Ya enviaste muchas sugerencias hoy. Mañana puedes enviar más.'), findsOneWidget);
    expect(find.text('Otra idea más para la app.'), findsOneWidget);
    expect(find.text('¡Gracias!'), findsNothing);
  });

  test('la app no enlaza a la página de apoyo ni habla de pagos (política de Google Play)', () {
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final code = f.readAsStringSync().toLowerCase();
      for (final word in ['/apoyo', 'paypal', 'zelle', 'apoya mi desarrollo']) {
        expect(code.contains(word), isFalse, reason: '${f.path} menciona «$word»');
      }
    }
  });
}
