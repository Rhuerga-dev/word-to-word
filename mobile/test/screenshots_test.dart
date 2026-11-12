// Capturas para la ficha de Google Play. Solo corre con --dart-define=SHOTS=true (tarea w2w-shots):
// la app de verdad, con su menú, alimentada con los datos de un alumno de la demo (test/fixtures/,
// tarea w2w-fixtures). Nada de datos reales. Guarda las imágenes en store/screenshots/.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:word_to_word/app.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/routing/routes.dart';
import 'package:word_to_word/core/services/audio_service.dart';
import 'package:word_to_word/features/auth/data/user_profile.dart';
import 'package:word_to_word/features/auth/presentation/auth_controller.dart';

const shots = bool.fromEnvironment('SHOTS');

/// La API responde con los archivos de test/fixtures (lo que devolvió el servidor a un alumno de la demo).
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

Future<void> _fonts() async {
  // Las fuentes de W2W (test/fonts, bajadas por fetch.py) con el nombre de familia que usa google_fonts.
  for (final f in Directory('test/fonts').listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
    var family = f.uri.pathSegments.last.replaceAll('.ttf', '');
    // Las de respaldo van con el nombre corto que usa el tema (NotoSans, NotoEmoji).
    if (family.startsWith('NotoSans_')) family = 'NotoSans';
    if (family.startsWith('NotoEmoji_')) family = 'NotoEmoji';
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
  final dir = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  // "FlutterTest" es la fuente por defecto (y de respaldo) en las pruebas: Roboto, como en Android.
  for (final (family, files) in [
    ('FlutterTest', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']),
    ('Ahem', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']),
    ('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']),
    ('MaterialIcons', ['MaterialIcons-Regular.otf']),
  ]) {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File('$dir/$f');
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }
}

void main() {
  final key = GlobalKey();

  setUpAll(() async {
    if (!shots) return;
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
    // Carpetas de la app (caché sin conexión, traducciones): una temporal.
    PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('w2w-shots').path);
    await _fonts();
  });

  testWidgets('capturas de W2W', (tester) async {
    // Fuentes ya cargadas desde test/fonts: google_fonts no baja nada (y su aviso de "no está en assets" se ignora).
    GoogleFonts.config.allowRuntimeFetching = false;
    final onError = FlutterError.onError;
    FlutterError.onError = (d) => '${d.exception}'.contains('GoogleFonts') || '${d.exception}'.contains('google_fonts') ? null : onError?.call(d);
    addTearDown(() => FlutterError.onError = onError);
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final api = Api(dio: Dio(BaseOptions(baseUrl: 'https://w2w.huergalabs.dev/api'))..httpClientAdapter = _Fixtures());
    // ignore: avoid_print
    print('arrancando la app…');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(_Signed.new),
        headphonesProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: RepaintBoundary(key: key, child: const WordToWordApp()),
    ));

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> shoot(String name) async {
      // ignore: avoid_print
      print('captura $name…');
      await settle();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.625);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('store/screenshots/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    GoRouter router() => GoRouter.of(tester.element(find.byType(Scaffold).first));

    router().go(Routes.path);
    await shoot('2-camino');
    router().go(Routes.practice);
    await shoot('3-practica');
    router().go(Routes.progress);
    await shoot('4-progreso');
    // Hoy al final: para entonces ya cargó todo lo que usa (camino, perfil, sesión del día).
    router().go(Routes.today);
    await shoot('1-hoy');
  }, skip: !shots, timeout: const Timeout(Duration(minutes: 3)));
}
