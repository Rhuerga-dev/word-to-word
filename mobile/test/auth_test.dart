import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/features/auth/presentation/auth_controller.dart';

/// Servidor falso: responde según la ruta y guarda qué token llegó en cada petición.
class _Server implements HttpClientAdapter {
  final seen = <String, String?>{};
  String password = 'secreta123';
  bool tokenValid = true;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final path = o.uri.path.replaceFirst(RegExp(r'^.*?/api'), '');
    seen[path] = o.headers['Authorization'] as String?;
    ResponseBody json(Object data, [int status = 200]) =>
        ResponseBody.fromString(jsonEncode(data), status, headers: {Headers.contentTypeHeader: ['application/json']});

    switch (path) {
      case '/auth/login':
        final data = o.data as Map;
        if (data['password'] != password) {
          return json({'message': 'x', 'errors': {'email': ['Correo o contraseña incorrectos.']}}, 422);
        }
        return json({'token': 'tok-1'});
      case '/me':
        if (!tokenValid || o.headers['Authorization'] != 'Bearer tok-1') return json({'message': 'Unauthenticated.'}, 401);
        return json(jsonDecode(File('test/fixtures/me.json').readAsStringSync()));
      default:
        return json({});
    }
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Server server;
  late Api api;
  late ProviderContainer c;

  ProviderContainer make() {
    server = _Server();
    api = Api(baseUrl: 'https://test/api')..dio.httpClientAdapter = server;
    return ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
  }

  tearDown(() => c.dispose());

  Future<String?> storedToken() => const FlutterSecureStorage().read(key: 'token');

  test('entrar: guarda el token, lo manda en /me y queda el perfil', () async {
    FlutterSecureStorage.setMockInitialValues({});
    c = make();
    expect(await c.read(authControllerProvider.future), isNull);

    await c.read(authControllerProvider.notifier).login('ana@example.com', 'secreta123');

    expect(c.read(authControllerProvider).valueOrNull?.name, 'Invitado');
    expect(server.seen['/me'], 'Bearer tok-1');
    expect(await storedToken(), 'tok-1');
  });

  test('contraseña mal: muestra el mensaje del servidor y no guarda nada', () async {
    FlutterSecureStorage.setMockInitialValues({});
    c = make();
    await c.read(authControllerProvider.future);

    await expectLater(
      c.read(authControllerProvider.notifier).login('ana@example.com', 'otra'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Correo o contraseña incorrectos.').having((e) => e.status, 'status', 422)),
    );
    expect(c.read(authControllerProvider).valueOrNull, isNull);
    expect(await storedToken(), isNull);
  });

  test('al abrir la app con token guardado entra sola; si ya no vale, vuelve al login y lo borra', () async {
    FlutterSecureStorage.setMockInitialValues({'token': 'tok-1'});
    c = make();
    expect((await c.read(authControllerProvider.future))?.name, 'Invitado');
    c.dispose();

    FlutterSecureStorage.setMockInitialValues({'token': 'tok-viejo'});
    c = make();
    expect(await c.read(authControllerProvider.future), isNull);
    expect(await storedToken(), isNull);
  });

  test('si una petición da 401 (sesión caducada), se sale de la cuenta', () async {
    FlutterSecureStorage.setMockInitialValues({'token': 'tok-1'});
    c = make();
    expect(await c.read(authControllerProvider.future), isNotNull);

    server.tokenValid = false;
    await expectLater(c.read(authControllerProvider.notifier).refreshProfile(), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));

    expect(c.read(authControllerProvider).valueOrNull, isNull);
    expect(api.token, isNull);
    expect(await storedToken(), isNull);
  });
}
