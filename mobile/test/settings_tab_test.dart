// La pestaña Ajustes: la app de verdad con los datos de la demo (test/fixtures/), sin red.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:word_to_word/app.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/services/audio_service.dart';
import 'package:word_to_word/features/auth/data/user_profile.dart';
import 'package:word_to_word/features/auth/presentation/auth_controller.dart';

import 'support/test_fonts.dart';

class _Fixtures implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final name = o.uri.path.replaceFirst(RegExp(r'^.*?/api/'), '').replaceAll('/', '_');
    final f = File('test/fixtures/$name.json');
    return ResponseBody.fromString(f.existsSync() ? f.readAsStringSync() : '{}', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
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
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
  @override
  Future<String?> getApplicationCachePath() async => dir;
}

class _Signed extends AuthController {
  @override
  Future<UserProfile?> build() async => UserProfile.fromJson(jsonDecode(File('test/fixtures/me.json').readAsStringSync()) as Map<String, dynamic>);
}

void main() {
  setUpAll(() async {
    for (final ch in [
      'com.ryanheise.just_audio.methods',
      'com.llfbandit.record/messages',
      'com.ryanheise.audio_session',
      'plugins.it_nomads.com/flutter_secure_storage',
      'dexterous.com/flutter/local_notifications',
      'flutter_timezone',
      'w2w/airpods',
      'de.ffuf.in_app_update/methods',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
    }
    PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('w2w-settings').path);
    await useTestFonts();
  });

  testWidgets('Ajustes es una pestaña: recordatorio y cuenta ahí, y ya no en Progreso', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final api = Api(dio: Dio(BaseOptions(baseUrl: 'https://test/api'))..httpClientAdapter = _Fixtures());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(_Signed.new),
        headphonesProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const WordToWordApp(),
    ));

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await settle();
    final nav = find.byType(NavigationBar);
    expect(find.descendant(of: nav, matching: find.byType(NavigationDestination)), findsNWidgets(5));

    await tester.tap(find.descendant(of: nav, matching: find.text('Ajustes')));
    await settle();
    expect(find.text('Avisarme si no he estudiado'), findsOneWidget);
    expect(find.text('Salir'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Borrar mi cuenta'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Borrar mi cuenta'), findsOneWidget);

    await tester.tap(find.descendant(of: nav, matching: find.text('Progreso')));
    await settle();
    expect(find.text('Liga de la semana'), findsOneWidget);
    expect(find.text('Avisarme si no he estudiado'), findsNothing);
  });
}
