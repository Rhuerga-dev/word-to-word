// Ajustes → «Qué aprendes»: elegir curso. Solo sale si hay más de uno; cambiar avisa al servidor.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/features/settings/presentation/course_card.dart';

import 'support/test_fonts.dart';

const _english = {'code': 'en-es', 'name': 'Inglés para hispanohablantes', 'learn': 'en', 'from': 'es', 'active': true};
const _spanish = {'code': 'es-en', 'name': 'Spanish for English speakers', 'learn': 'es', 'from': 'en', 'active': false};

/// Un servidor de mentira: recuerda el curso elegido y apunta lo que se le pide.
class _Server implements HttpClientAdapter {
  _Server(this.courses, {this.fail = false});
  final List<Map<String, Object>> courses;
  final bool fail;
  String current = 'en-es';
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final path = o.uri.path.replaceFirst(RegExp(r'^.*?/api/'), '');
    calls.add('${o.method} $path${o.data is Map ? ' ${jsonEncode(o.data)}' : ''}');
    final h = {Headers.contentTypeHeader: ['application/json']};
    if (fail) return ResponseBody.fromString('{"message":"boom"}', 500, headers: h);
    if (o.method == 'PUT' && path == 'course') current = (o.data as Map)['code'] as String;
    if (path == 'courses' || path == 'course') {
      return ResponseBody.fromString(jsonEncode({'current': current, 'courses': [for (final c in courses) {...c, 'current': c['code'] == current}]}), 200, headers: h);
    }
    return ResponseBody.fromString('{}', 200, headers: h);
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _open(WidgetTester tester, _Server server) async {
  final api = Api(dio: Dio(BaseOptions(baseUrl: 'https://test/api'))..httpClientAdapter = server);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiProvider.overrideWithValue(api)],
    child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: CourseCard()))),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(useTestFonts);

  testWidgets('con un solo curso no sale nada: la app queda como siempre', (tester) async {
    await _open(tester, _Server([_english]));
    expect(find.text('Qué aprendes'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('con un servidor viejo o caído tampoco sale, y no rompe la pantalla', (tester) async {
    await _open(tester, _Server([_english, _spanish], fail: true));
    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con dos cursos se ve cuál es el tuyo y cuál está en construcción', (tester) async {
    await _open(tester, _Server([_english, _spanish]));

    expect(find.text('Qué aprendes'), findsOneWidget);
    expect(find.text('Inglés para hispanohablantes'), findsOneWidget);
    expect(find.text('Spanish for English speakers'), findsOneWidget);
    expect(find.text('En construcción (solo para probar)'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('course-en-es'))).selected, isTrue);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('course-es-en'))).selected, isFalse);
    expect(find.text('Cada curso guarda su progreso aparte: al cambiar no pierdes nada.'), findsOneWidget);
  });

  testWidgets('tocar otro curso lo cambia en el servidor y la marca pasa a él', (tester) async {
    final server = _Server([_english, _spanish]);
    await _open(tester, server);

    await tester.tap(find.byKey(const ValueKey('course-es-en')));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(server.calls, contains('PUT course {"code":"es-en"}'));
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('course-es-en'))).selected, isTrue);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('course-en-es'))).selected, isFalse);

    // Tocar el que ya tienes no hace nada.
    final before = server.calls.length;
    await tester.tap(find.byKey(const ValueKey('course-es-en')));
    await tester.pump();
    expect(server.calls.length, before);
  });

  test('lo que no se entiende del servidor se ignora', () {
    expect(CourseOption.tryParse({'code': 'es-en', 'name': 'Spanish', 'learn': 'es'})!.flag, '🇪🇸');
    expect(CourseOption.tryParse({'code': 'xx', 'name': 'Otro'})!.flag, '🌐');
    expect(CourseOption.tryParse({'name': 'Sin código'}), isNull);
    expect(CourseOption.tryParse('nada'), isNull);
  });
}
