// La bienvenida de la mascota (nace y le pones nombre), cambiarle el nombre y los avisos con su voz.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/services/reminder_service.dart';
import 'package:word_to_word/core/storage/offline_cache.dart';
import 'package:word_to_word/features/pet/data/pet.dart';
import 'package:word_to_word/features/pet/presentation/pet_birth.dart';
import 'package:word_to_word/features/pet/presentation/pet_providers.dart';

import 'support/test_fonts.dart';

Map<String, dynamic> _petJson({String name = 'Brainy', bool? named, bool? welcomed, int stage = 0, int points = 0}) => {
      'name': name,
      if (named != null) 'named': named,
      if (welcomed != null) 'welcomed': welcomed,
      'points': points,
      'stage': {'index': stage, 'key': const ['spark', 'sprout', 'curious', 'chatty', 'wise'][stage], 'count': 5, 'progress': 0.2, 'next': 15},
      'regions': <String, dynamic>{},
    };

/// Servidor de mentira para PUT /pet/name: apunta lo que recibe y responde la mascota con ese nombre.
class _Server implements HttpClientAdapter {
  _Server({this.status = 200, this.error});
  final int status;
  final String? error;
  final sent = <Map<String, dynamic>>[];
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    paths.add('${o.method} ${o.uri.path}');
    final data = Map<String, dynamic>.from(o.data as Map);
    sent.add(data);
    final name = data['name'] as String?;
    final reply = status == 200 ? _petJson(name: name ?? 'Brainy', named: name != null, welcomed: true) : {'message': error};
    return ResponseBody.fromString(jsonEncode(reply), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Abre la bienvenida encima de una pantalla «Hoy» de mentira (para comprobar que al terminar se cierra).
Future<void> _open(WidgetTester tester, _Server server, {PetState? pet, bool reduceMotion = true}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final api = Api(dio: Dio(BaseOptions(baseUrl: 'https://test/api'))..httpClientAdapter = server);
  final dir = Directory.systemTemp.createTempSync('w2w-birth');
  final shown = pet ?? PetState.tryParse(_petJson(welcomed: false))!;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(api),
      offlineCacheProvider.overrideWithValue(OfflineCache(api, dir: () async => dir)),
      petProvider.overrideWith((ref) async => shown),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => PetBirthPage(pet: shown))),
              child: const Text('Hoy'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Hoy'));
  await _run(tester);
}

/// Deja pasar cuadros y un poco de tiempo real, para que la petición de mentira termine.
Future<void> _run(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(useTestFonts);

  group('Datos', () {
    test('lee el nombre, si lo eligió el alumno y si ya fue presentada', () {
      final pet = PetState.tryParse(_petJson(name: 'Luna', named: true, welcomed: true))!;
      expect((pet.name, pet.named, pet.welcomed), ('Luna', true, true));
      final baby = PetState.tryParse(_petJson(named: false, welcomed: false))!;
      expect((baby.name, baby.named, baby.welcomed), ('Brainy', false, false));
    });

    test('con un servidor viejo (no lo dice) no se enseña la bienvenida', () {
      final pet = PetState.tryParse(_petJson())!;
      expect(pet.welcomed, isTrue);
      expect(pet.named, isFalse);
      expect(const PetState().welcomed, isTrue);
    });
  });

  group('Bienvenida', () {
    testWidgets('recién nacida: saluda y pregunta cómo llamarla', (tester) async {
      await _open(tester, _Server());
      expect(find.text('¡Hola! Acabo de nacer.'), findsOneWidget);
      expect(find.text('¿Cómo me quieres llamar?'), findsOneWidget);
      expect(find.byKey(const ValueKey('pet-name-field')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('alumno de antes, con la mascota ya crecida: no dice que acaba de nacer', (tester) async {
      await _open(tester, _Server(), pet: PetState.tryParse(_petJson(welcomed: false, stage: 2, points: 80))!);
      expect(find.text('¡Hola! Soy tu mascota.'), findsOneWidget);
      expect(find.text('¡Hola! Acabo de nacer.'), findsNothing);
    });

    testWidgets('le pones nombre: se guarda, se presenta con él y al empezar se cierra', (tester) async {
      final server = _Server();
      await _open(tester, server);
      await tester.enterText(find.byKey(const ValueKey('pet-name-field')), '  Luna  ');
      await tester.tap(find.byKey(const ValueKey('pet-name-save')));
      await _run(tester);

      expect(server.paths, ['PUT /api/pet/name']);
      expect(server.sent.single, {'name': 'Luna'});
      expect(find.text('¡Me llamo Luna!'), findsOneWidget);
      expect(find.text('Tengo hambre de palabras. ¿Me enseñas la primera?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pet-birth-start')));
      await _run(tester);
      expect(find.byType(PetBirthPage), findsNothing);
      expect(find.text('Hoy'), findsOneWidget);
    });

    testWidgets('«Luego»: se queda como Brainy, queda apuntado y se cierra', (tester) async {
      final server = _Server();
      await _open(tester, server);
      await tester.tap(find.byKey(const ValueKey('pet-name-later')));
      await _run(tester);

      expect(server.sent.single, {'name': null});
      expect(find.byType(PetBirthPage), findsNothing);
    });

    testWidgets('«Luego» cierra aunque el servidor falle (se preguntará otro día)', (tester) async {
      await _open(tester, _Server(status: 500, error: 'Error del servidor'));
      await tester.tap(find.byKey(const ValueKey('pet-name-later')));
      await _run(tester);
      expect(find.byType(PetBirthPage), findsNothing);
    });

    testWidgets('un nombre de una letra no se envía y lo dice', (tester) async {
      final server = _Server();
      await _open(tester, server);
      await tester.enterText(find.byKey(const ValueKey('pet-name-field')), 'L');
      await tester.tap(find.byKey(const ValueKey('pet-name-save')));
      await _run(tester, 2);
      expect(find.text('Escribe un nombre de al menos 2 letras.'), findsOneWidget);
      expect(server.sent, isEmpty);
    });

    testWidgets('si el servidor no acepta el nombre, enseña su mensaje y deja corregirlo', (tester) async {
      final server = _Server(status: 422, error: 'El nombre debe tener de 2 a 20 letras o números.');
      await _open(tester, server);
      await tester.enterText(find.byKey(const ValueKey('pet-name-field')), 'Luna!!');
      await tester.tap(find.byKey(const ValueKey('pet-name-save')));
      await _run(tester);
      expect(find.text('El nombre debe tener de 2 a 20 letras o números.'), findsOneWidget);
      expect(find.byKey(const ValueKey('pet-name-field')), findsOneWidget);
      expect(find.textContaining('Me llamo'), findsNothing);
    });

    testWidgets('con animación: la pregunta espera a que nazca, y tocar la pantalla la adelanta', (tester) async {
      await _open(tester, _Server(), reduceMotion: false);
      AnimatedOpacity question() => tester.widget<AnimatedOpacity>(find.ancestor(of: find.text('¿Cómo me quieres llamar?'), matching: find.byType(AnimatedOpacity)).first);
      expect(question().opacity, 0, reason: 'todavía está naciendo');

      await tester.tapAt(const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 50));
      expect(question().opacity, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la animación entera corre sin errores y termina en la pregunta', (tester) async {
      await _open(tester, _Server(), reduceMotion: false);
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
      final question = tester.widget<AnimatedOpacity>(find.ancestor(of: find.text('¿Cómo me quieres llamar?'), matching: find.byType(AnimatedOpacity)).first);
      expect(question.opacity, 1);
    });
  });

  group('Cambiar el nombre después', () {
    testWidgets('el cuadro de Ajustes guarda el nombre nuevo', (tester) async {
      final server = _Server();
      final api = Api(dio: Dio(BaseOptions(baseUrl: 'https://test/api'))..httpClientAdapter = server);
      final dir = Directory.systemTemp.createTempSync('w2w-rename');
      final pet = PetState.tryParse(_petJson(name: 'Luna', named: true, welcomed: true))!;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          offlineCacheProvider.overrideWithValue(OfflineCache(api, dir: () async => dir)),
          petProvider.overrideWith((ref) async => pet),
        ],
        child: MaterialApp(home: Scaffold(body: PetNameDialog(pet: pet))),
      ));
      await tester.pump();
      expect(find.text('Luna'), findsOneWidget, reason: 'empieza con el nombre que ya tiene');

      await tester.enterText(find.byKey(const ValueKey('pet-rename-field')), 'Sol');
      await tester.tap(find.byKey(const ValueKey('pet-rename-save')));
      await _run(tester);
      expect(server.sent.single, {'name': 'Sol'});
    });
  });

  group('Avisos con la voz de la mascota', () {
    test('con mascota, cada aviso lleva su nombre', () {
      final texts = ReminderService.messages('Luna');
      expect(texts.length, 4);
      for (final (title, body) in texts) {
        expect(title, contains('Luna'));
        expect(body, isNotEmpty);
      }
      expect(texts.first.$1, 'Luna tiene hambre de palabras');
    });

    test('sin nombre elegido habla Brainy', () {
      expect(ReminderService.messages('Brainy').first.$1, 'Brainy tiene hambre de palabras');
    });

    test('sin mascota (servidor viejo), los avisos de siempre', () {
      expect(ReminderService.messages().first.$1, 'Tu sesión de hoy te espera');
      expect(ReminderService.messages('  ').first.$1, 'Tu sesión de hoy te espera');
    });

    test('la mascota nunca culpa ni dramatiza', () {
      final all = ReminderService.messages('Luna').map((m) => '${m.$1} ${m.$2}'.toLowerCase()).join(' ');
      for (final word in ['muere', 'morir', 'triste', 'abandon', 'culpa', 'llora', 'enferm', 'pierd', 'olvidaste']) {
        expect(all.contains(word), isFalse, reason: 'un aviso dice «$word»');
      }
    });
  });
}
