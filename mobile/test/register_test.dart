// Crear cuenta con código de invitación: la pantalla de entrar de verdad, con un servidor falso.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/theme/app_theme.dart';
import 'package:word_to_word/features/auth/presentation/auth_controller.dart';
import 'package:word_to_word/features/auth/presentation/login_page.dart';

import 'support/test_fonts.dart';

/// Servidor falso: /config dice si hace falta código; /auth/register guarda lo que llegó.
class _Server implements HttpClientAdapter {
  bool inviteRequired = true;
  bool closed = false; // migración sin aplicar: 503
  Map? registered;
  List<Map<String, String>> courses = const []; // cursos abiertos que ofrece /config

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final path = o.uri.path.replaceFirst(RegExp(r'^.*?/api'), '');
    ResponseBody json(Object data, [int status = 200]) =>
        ResponseBody.fromString(jsonEncode(data), status, headers: {Headers.contentTypeHeader: ['application/json']});

    switch (path) {
      case '/config':
        return json({'ai': true, 'invite_required': inviteRequired, if (courses.isNotEmpty) 'courses': courses});
      case '/auth/register':
        if (closed) return json({'message': 'El registro está cerrado un momento. Vuelve a intentarlo más tarde.'}, 503);
        final data = o.data as Map;
        if (data['invite'] != 'FAMILIA') {
          return json({'message': 'Código de invitación no válido.', 'errors': {'invite': ['Código de invitación no válido.']}}, 422);
        }
        registered = data;
        return json({'token': 'tok-1'});
      case '/me':
        return json(jsonDecode(File('test/fixtures/me.json').readAsStringSync()));
      default:
        return json({});
    }
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), (_) async => 'Europe/Madrid');
    await useTestFonts();
  });

  late _Server server;
  late ProviderContainer c;

  Future<void> open(WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    final api = Api(baseUrl: 'https://test/api')..dio.httpClientAdapter = server;
    c = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: W.theme(), home: const LoginPage()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿No tienes cuenta? Crea una con tu código de invitación'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String invite) async {
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Ana');
    await tester.enterText(find.widgetWithText(TextField, 'Correo'), 'ana@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Contraseña'), 'secreta1234');
    await tester.enterText(find.byKey(const Key('invite')), invite);
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
  }

  const english = {'code': 'en-es', 'name': 'Inglés para hispanohablantes', 'learn': 'en', 'from': 'es'};
  const spanish = {'code': 'es-en', 'name': 'Spanish for English speakers', 'learn': 'es', 'from': 'en'};

  testWidgets('con un solo curso (o un servidor viejo) no se pregunta qué aprender ni se manda nada', (tester) async {
    server = _Server()..courses = [english];
    await open(tester);

    expect(find.text('¿Qué quieres aprender?'), findsNothing);
    await fill(tester, 'familia');
    expect(server.registered?.containsKey('course'), isFalse);
  });

  testWidgets('con dos cursos abiertos se elige uno al registrarse y se manda al servidor', (tester) async {
    server = _Server()..courses = [english, spanish];
    await open(tester);

    expect(find.text('¿Qué quieres aprender?'), findsOneWidget);
    expect(find.text('Inglés para hispanohablantes'), findsOneWidget);
    expect(find.text('Spanish for English speakers'), findsOneWidget);

    await tester.tap(find.byKey(const Key('signup-course-es-en')));
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(find.byKey(const Key('signup-course-es-en'))).selected, isTrue);

    await fill(tester, 'familia');
    expect(server.registered?['course'], 'es-en');
  });

  testWidgets('crear cuenta: muestra el código, lo pasa a mayúsculas y lo manda como invite', (tester) async {
    server = _Server();
    await open(tester);

    expect(find.text('Código de invitación'), findsOneWidget);
    expect(find.text('W2W es solo por invitación. Pide un código a quien te invitó.'), findsOneWidget);

    await fill(tester, 'familia');
    expect(find.text('FAMILIA'), findsOneWidget); // se ve en mayúsculas
    expect(server.registered?['invite'], 'FAMILIA');
    expect(server.registered?['email'], 'ana@example.com');
    expect(server.registered?['timezone'], 'Europe/Madrid');
    expect(c.read(authControllerProvider).valueOrNull?.name, 'Invitado');
  });

  testWidgets('código mal: el error sale debajo del campo, sin repetirlo arriba', (tester) async {
    server = _Server();
    await open(tester);
    await fill(tester, 'w2w-0000-0000');

    expect(find.text('Código de invitación no válido.'), findsOneWidget);
    expect(c.read(authControllerProvider).valueOrNull, isNull);
  });

  testWidgets('registro cerrado (503): muestra el mensaje del servidor', (tester) async {
    server = _Server()..closed = true;
    await open(tester);
    await fill(tester, 'FAMILIA');

    expect(find.text('El registro está cerrado un momento. Vuelve a intentarlo más tarde.'), findsOneWidget);
  });

  testWidgets('si el servidor no pide código, el campo no aparece', (tester) async {
    server = _Server()..inviteRequired = false;
    await open(tester);

    expect(find.byKey(const Key('invite')), findsNothing);
    expect(find.widgetWithText(TextField, 'Nombre'), findsOneWidget);
  });
}
