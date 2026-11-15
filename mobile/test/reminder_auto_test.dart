// Ajustes → recordatorio automático: el interruptor, sus textos y que se manda `auto` al servidor.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/theme/app_theme.dart';
import 'package:word_to_word/features/auth/data/user_profile.dart';
import 'package:word_to_word/features/auth/presentation/auth_controller.dart';
import 'package:word_to_word/features/settings/presentation/settings_page.dart';

import 'support/test_fonts.dart';

Map<String, dynamic> _me(Map<String, dynamic> reminder) =>
    (jsonDecode(File('test/fixtures/me.json').readAsStringSync()) as Map<String, dynamic>)..['reminder'] = reminder;

/// Fixtures para lo demás; PUT /reminders responde con el perfil ya en automático (con hora habitual).
class _Adapter implements HttpClientAdapter {
  final puts = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final path = o.uri.path.replaceFirst(RegExp(r'^.*?/api/'), '');
    final h = {Headers.contentTypeHeader: ['application/json']};
    if (o.method == 'PUT' && path == 'reminders') {
      final sent = Map<String, dynamic>.from(o.data as Map);
      puts.add(sent);
      final r = {...sent, 'usual_time': sent['auto'] == true ? '08:15' : null};
      return ResponseBody.fromString(jsonEncode(_me(r)), 200, headers: h);
    }
    final f = File('test/fixtures/${path.replaceAll('/', '_')}.json');
    return ResponseBody.fromString(f.existsSync() ? f.readAsStringSync() : '{}', 200, headers: h);
  }

  @override
  void close({bool force = false}) {}
}

class _TempPaths extends PathProviderPlatform {
  _TempPaths(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

class _Signed extends AuthController {
  _Signed(this.reminder);
  final Map<String, dynamic> reminder;
  @override
  Future<UserProfile?> build() async => UserProfile.fromJson(_me(reminder));
}

void main() {
  final scheduled = <MethodCall>[];

  setUpAll(() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith(); // en el teléfono lo hace Flutter solo
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['plugins.it_nomads.com/flutter_secure_storage', 'flutter_timezone']) {
      m.setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
    }
    m.setMockMethodCallHandler(const MethodChannel('dexterous.com/flutter/local_notifications'), (call) async {
      if (call.method == 'zonedSchedule') scheduled.add(call);
      return call.method == 'requestNotificationsPermission' || call.method == 'initialize' ? true : null;
    });
    PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('w2w-reminder').path);
    await useTestFonts();
  });

  Future<_Adapter> open(WidgetTester tester, Map<String, dynamic> reminder) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final adapter = _Adapter();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(Api(dio: Dio(BaseOptions(baseUrl: 'https://test/api'))..httpClientAdapter = adapter)),
        authControllerProvider.overrideWith(() => _Signed(reminder)),
      ],
      child: MaterialApp(theme: W.theme(), home: const Scaffold(body: SettingsPage())),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    return adapter;
  }

  const autoLabel = 'Automático: a la hora en que sueles practicar';

  testWidgets('apagado el recordatorio, no sale el interruptor automático', (tester) async {
    await open(tester, {'enabled': false, 'time': '19:00'});
    expect(find.text(autoLabel), findsNothing);
  });

  testWidgets('automático sin hora habitual: usa la hora elegida', (tester) async {
    await open(tester, {'enabled': true, 'time': '20:30', 'auto': true, 'usual_time': null});
    expect(find.text(autoLabel), findsOneWidget);
    expect(find.text('Usaremos las 20:30 hasta conocer tu hora habitual'), findsOneWidget);
  });

  testWidgets('al encenderlo manda auto y programa el aviso a la hora habitual + 30 min', (tester) async {
    final adapter = await open(tester, {'enabled': true, 'time': '19:00', 'auto': false});
    expect(find.text('Te avisaremos hacia las 08:15'), findsNothing);

    scheduled.clear();
    await tester.tap(find.text(autoLabel));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(adapter.puts.single['auto'], isTrue);
    expect(adapter.puts.single['time'], '19:00');
    expect(find.text('Te avisaremos hacia las 08:15'), findsOneWidget);
    expect(scheduled, isNotEmpty);
    // La hora va en UTC: se compara con 08:45 hora local convertida.
    final args = Map<Object?, Object?>.from(scheduled.first.arguments as Map);
    final at = DateTime.parse('${args['scheduledDateTime']}Z').toLocal();
    expect((at.hour, at.minute), (8, 45));
  });
}
