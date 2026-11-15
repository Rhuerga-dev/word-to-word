// Protectores de racha, «Tu semana hablando» y recordatorio automático: lectura del JSON, la tarjeta y la pestaña Progreso.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/storage/offline_cache.dart';
import 'package:word_to_word/core/theme/app_theme.dart';
import 'package:word_to_word/features/auth/data/user_profile.dart';
import 'package:word_to_word/features/progress/data/progress_models.dart';
import 'package:word_to_word/features/progress/data/progress_repository.dart';
import 'package:word_to_word/features/progress/presentation/progress_page.dart';
import 'package:word_to_word/features/progress/presentation/progress_providers.dart';
import 'package:word_to_word/features/progress/presentation/weekly_card.dart';

import 'support/test_fonts.dart';

const _weekly = {
  'from': '2026-11-09',
  'to': '2026-11-15',
  'now': {'minutes': 12.5, 'sessions': 4, 'days': 3, 'words': 900, 'wpm': 96, 'reaction': 1.8, 'pauses_per_min': 2.1, 'mistakes_new': 3, 'mistakes_mastered': 5},
  'before': {'minutes': 8, 'sessions': 2, 'days': 2, 'words': 500, 'wpm': 90, 'reaction': 2.4, 'pauses_per_min': 3.0, 'mistakes_new': 4, 'mistakes_mastered': 7},
  'conquered': [
    {'said': 'I have 30 years', 'correct': 'I am 30 years old'},
  ],
};

const _emptyWeek = {
  'now': {'minutes': 0, 'sessions': 0, 'days': 0, 'words': 0, 'wpm': null, 'reaction': null, 'pauses_per_min': null, 'mistakes_new': 0, 'mistakes_mastered': 0},
  'before': {'minutes': 4, 'sessions': 1, 'days': 1, 'words': 200, 'wpm': 80, 'reaction': 2.0, 'pauses_per_min': null, 'mistakes_new': 0, 'mistakes_mastered': 0},
  'conquered': [],
};

Map<String, dynamic> _fixture(String name) => jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

/// GET /progress de la demo con los protectores de racha en vocab (servidor nuevo).
Map<String, dynamic> _progress({int freezes = 0, bool protected = false}) {
  final p = _fixture('progress');
  return p..['vocab'] = {...p['vocab'] as Map, 'streak_freezes': freezes, 'streak_protected': protected};
}

/// Responde con los fixtures; /progress y /speaking/weekly con lo que diga cada test (weekly null = 404, servidor viejo).
class _Adapter implements HttpClientAdapter {
  _Adapter({this.progress, this.weekly});
  final Object? progress, weekly;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final path = o.uri.path.replaceFirst(RegExp(r'^.*?/api/'), '');
    final Object? data = switch (path) {
      'progress' when progress != null => progress,
      'speaking/weekly' => weekly,
      _ => File('test/fixtures/${path.replaceAll('/', '_')}.json').existsSync() ? _fixture(path.replaceAll('/', '_')) : <String, dynamic>{},
    };
    final h = {Headers.contentTypeHeader: ['application/json']};
    return data == null ? ResponseBody.fromString('{"message":"Not Found"}', 404, headers: h) : ResponseBody.fromString(jsonEncode(data), 200, headers: h);
  }

  @override
  void close({bool force = false}) {}
}

ProgressRepository _repo(_Adapter a) {
  final api = Api(dio: Dio(BaseOptions(baseUrl: 'https://test/api'))..httpClientAdapter = a);
  final dir = Directory.systemTemp.createTempSync('w2w-progress');
  return ProgressRepository(api, OfflineCache(api, dir: () async => dir));
}

void main() {
  group('Protectores de racha', () {
    test('se leen de vocab (GET /progress)', () {
      final d = ProgressData.fromJson(_progress(freezes: 2, protected: true));
      expect(d.streakFreezes, 2);
      expect(d.streakProtected, isTrue);
      final off = ProgressData.fromJson(_progress(freezes: 1, protected: false));
      expect(off.streakFreezes, 1);
      expect(off.streakProtected, isFalse);
    });

    test('servidor viejo (sin los campos): 0 y false', () {
      final d = ProgressData.fromJson(_fixture('progress'));
      expect(d.streak, 12);
      expect(d.streakFreezes, 0);
      expect(d.streakProtected, isFalse);
    });
  });

  group('Informe semanal', () {
    test('lee todos los campos y los null', () {
      final w = WeeklyFluency.fromJson(_weekly);
      expect(w.now.minutes, 12.5);
      expect(w.now.wpm, 96);
      expect(w.now.reaction, 1.8);
      expect(w.before.mistakesMastered, 7);
      expect(w.conquered, [('I have 30 years', 'I am 30 years old')]);
      expect(w.now.empty, isFalse);

      final e = WeeklyFluency.fromJson(_emptyWeek);
      expect(e.now.empty, isTrue);
      expect(e.now.wpm, isNull);
      expect(e.now.reaction, isNull);
      expect(WeeklyFluency.fromJson(const {}).now.empty, isTrue);
    });

    test('cambio: flecha, verde si mejora y la reacción mejora al bajar', () {
      expect(change(12.5, 8)!.text, '↑ 4.5');
      expect(change(12.5, 8)!.better, isTrue);
      expect(change(5, 7)!.text, '↓ 2');
      expect(change(5, 7)!.better, isFalse);
      expect(change(1.8, 2.4, lowerIsBetter: true)!.better, isTrue);
      expect(change(3, 2.4, lowerIsBetter: true)!.better, isFalse);
      expect(change(4, 4)!.text, '=');
      expect(change(4, 4)!.better, isNull);
      expect(change(null, 4), isNull);
      expect(change(4, null), isNull);
    });

    test('el repositorio trae los protectores y /speaking/weekly', () async {
      final b = await _repo(_Adapter(progress: _progress(freezes: 1, protected: true), weekly: _weekly)).fetch();
      expect(b.progress.streakFreezes, 1);
      expect(b.progress.streakProtected, isTrue);
      expect(b.weekly?.now.wpm, 96);
    });

    test('servidor viejo (404): la pestaña sale como antes', () async {
      final b = await _repo(_Adapter()).fetch();
      expect(b.progress.streak, 12);
      expect(b.progress.streakFreezes, 0);
      expect(b.weekly, isNull);
    });
  });

  group('Recordatorio automático', () {
    test('lee auto y usual_time; sin ellos, como antes', () {
      final r = Reminder.fromJson({'enabled': true, 'time': '19:00', 'auto': true, 'usual_time': '08:15'});
      expect(r.auto, isTrue);
      expect(r.usualTime, '08:15');
      final old = Reminder.fromJson({'enabled': true, 'time': '19:00'});
      expect(old.auto, isFalse);
      expect(old.usualTime, isNull);
      expect(old.deviceTime, '19:00');
    });

    test('el teléfono avisa a la hora habitual + 30 min', () {
      expect(const Reminder(enabled: true, time: '19:00', auto: true, usualTime: '08:15').deviceTime, '08:45');
      expect(const Reminder(enabled: true, time: '19:00', auto: true, usualTime: '23:45').deviceTime, '00:15');
      // Aún sin hora habitual, o sin automático: la hora elegida.
      expect(const Reminder(enabled: true, time: '19:00', auto: true).deviceTime, '19:00');
      expect(const Reminder(enabled: true, time: '19:00', usualTime: '08:15').deviceTime, '19:00');
      expect(const Reminder(enabled: true, time: '19:00', auto: true, usualTime: 'xx').deviceTime, '19:00');
    });
  });

  group('Pantalla', () {
    setUpAll(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
      await useTestFonts();
    });

    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

    testWidgets('la tarjeta semanal: números, cambios en color y errores superados', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.pumpWidget(wrap(WeeklyCard(WeeklyFluency.fromJson(_weekly))));
      expect(find.text('Minutos hablando'), findsOneWidget);
      expect(find.text('12.5'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
      expect(find.text('1.8 s'), findsOneWidget);
      expect(find.text('Ya no dices «I have 30 years» → «I am 30 years old»'), findsOneWidget);

      Color colorOf(String t) => tester.widget<Text>(find.text(t)).style!.color!;
      expect(colorOf('↑ 4.5'), W.good); // más minutos
      expect(colorOf('↑ 6'), W.good); // más palabras por minuto
      expect(colorOf('↓ 0.6'), W.good); // reacción más rápida
      expect(colorOf('↓ 2'), W.bad); // menos errores superados que la semana pasada
    });

    testWidgets('semana vacía: lo dice y no inventa números', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.pumpWidget(wrap(WeeklyCard(WeeklyFluency.fromJson(_emptyWeek))));
      expect(find.text('Aún no hablaste esta semana'), findsOneWidget);
      expect(find.text('Palabras por minuto'), findsNothing);
      expect(find.text('Errores superados'), findsOneWidget);
      expect(find.textContaining('Ya no dices'), findsNothing);
    });

    testWidgets('Progreso: protectores junto a la racha, aviso y la semana', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      final bundle = ProgressBundle(
        ProgressData.fromJson(_progress(freezes: 2, protected: true)),
        League.fromJson(_fixture('league')),
        Achievements.fromJson(_fixture('achievements')),
        WeeklyFluency.fromJson(_weekly),
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [progressProvider.overrideWith((ref) async => bundle)],
        child: MaterialApp(theme: W.theme(), home: const Scaffold(body: ProgressPage())),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      expect(find.text('🛡️ ×2'), findsOneWidget);
      expect(find.text('🛡️ Tu racha está protegida: estudia hoy para no perderla'), findsOneWidget);
      expect(find.text('Tu semana hablando'), findsOneWidget);
      expect(find.byType(WeeklyCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Progreso sin protectores ni informe (servidor viejo): como antes', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      final bundle = ProgressBundle(ProgressData.fromJson(_fixture('progress')), League.fromJson(_fixture('league')), Achievements.fromJson(_fixture('achievements')));
      await tester.pumpWidget(ProviderScope(
        overrides: [progressProvider.overrideWith((ref) async => bundle)],
        child: MaterialApp(theme: W.theme(), home: const Scaffold(body: ProgressPage())),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      expect(find.textContaining('🛡️'), findsNothing);
      expect(find.text('Tu semana hablando'), findsNothing);
      expect(find.text('Liga de la semana'), findsOneWidget);
    });
  });
}
