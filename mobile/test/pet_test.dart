// Brainy, la mascota (Paso 6a): lectura del JSON, el repositorio, el cerebro y las pantallas.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_to_word/core/l10n/strings_en.dart';
import 'package:word_to_word/core/l10n/tr.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/routing/routes.dart';
import 'package:word_to_word/core/storage/offline_cache.dart';
import 'package:word_to_word/core/theme/app_theme.dart';
import 'package:word_to_word/features/pet/data/pet.dart';
import 'package:word_to_word/features/pet/data/pet_repository.dart';
import 'package:word_to_word/features/pet/presentation/pet_brain.dart';
import 'package:word_to_word/features/pet/presentation/pet_card.dart';
import 'package:word_to_word/features/pet/presentation/pet_figure.dart';
import 'package:word_to_word/features/pet/presentation/pet_page.dart';
import 'package:word_to_word/features/pet/presentation/pet_providers.dart';
import 'package:word_to_word/features/pet/presentation/pet_texts.dart';

import 'support/test_fonts.dart';

/// Lo que devuelve GET /api/pet (igual que tests/Feature/PetTest.php del servidor).
Map<String, dynamic> _pet({int stage = 1, String key = 'sprout', int points = 45, int? next = 60, double progress = 0.667, int words = 15, double level = 0.05}) => {
      'name': 'Brainy',
      'points': points,
      'stage': {'index': stage, 'key': key, 'count': 5, 'from': 15, 'next': next, 'progress': progress},
      'regions': {
        'words': {'count': words, 'target': 300, 'level': level},
        'memory': {'count': 5, 'target': 150, 'level': 0.033},
        'path': {'count': 2, 'target': 12, 'level': 0.167},
        'habit': {'count': 4, 'target': 30, 'level': 0.133},
        'links': {'level': 0.096},
      },
    };

PetState _full(int stage) => PetState(
      stage: stage,
      stageKey: const ['spark', 'sprout', 'curious', 'chatty', 'wise'][stage],
      stageProgress: 1,
      skills: {for (final r in PetRegion.values) r: const PetSkill(count: 10, target: 10, level: 1)},
    );

/// Responde a /pet con [body] (null = 404, servidor viejo) o corta la conexión si [down].
class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.down = false});
  Object? body;
  bool down;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (down) throw DioException.connectionError(requestOptions: o, reason: 'sin red');
    final h = {
      Headers.contentTypeHeader: ['application/json']
    };
    return body == null ? ResponseBody.fromString('{"message":"Not Found"}', 404, headers: h) : ResponseBody.fromString(jsonEncode(body), 200, headers: h);
  }

  @override
  void close({bool force = false}) {}
}

PetRepository _repo(_Adapter a) {
  final api = Api(dio: Dio(BaseOptions(baseUrl: 'https://test/api'))..httpClientAdapter = a);
  final dir = Directory.systemTemp.createTempSync('w2w-pet');
  return PetRepository(api, OfflineCache(api, dir: () async => dir));
}

void main() {
  group('Datos', () {
    test('lee la etapa, los puntos y cada zona', () {
      final p = PetState.tryParse(_pet())!;
      expect((p.name, p.points, p.stage, p.stageKey, p.stages, p.nextAt), ('Brainy', 45, 1, 'sprout', 5, 60));
      expect(p.stageProgress, closeTo(0.667, 0.001));
      expect(p.pointsToNext, 15);
      expect((p.skill(PetRegion.words).count, p.skill(PetRegion.words).target), (15, 300));
      expect(p.level(PetRegion.path), closeTo(0.167, 0.001));
      expect(p.level(PetRegion.links), closeTo(0.096, 0.001));
    });

    test('lo que no es una mascota da null (servidor viejo, respuesta vacía o rara)', () {
      expect(PetState.tryParse(const <String, dynamic>{}), isNull);
      expect(PetState.tryParse(null), isNull);
      expect(PetState.tryParse('hola'), isNull);
      expect(PetState.tryParse({'message': 'Not Found'}), isNull);
      expect(PetState.tryParse({'stage': 3, 'regions': <String, dynamic>{}}), isNull);
    });

    test('números fuera de rango se quedan dentro; campos que faltan valen 0', () {
      final p = PetState.tryParse({
        'stage': {'index': 99, 'count': 5, 'progress': 7, 'next': null},
        'regions': {
          'words': {'count': 5, 'target': 10, 'level': 3},
          'path': {'level': -2},
        },
      })!;
      expect((p.stage, p.stageProgress, p.nextAt, p.pointsToNext), (4, 1.0, null, 0));
      expect((p.level(PetRegion.words), p.level(PetRegion.path), p.level(PetRegion.memory)), (1.0, 0.0, 0.0));
    });
  });

  group('Repositorio', () {
    test('trae la mascota de GET /pet', () async {
      expect((await _repo(_Adapter(_pet())).fetch())?.points, 45);
    });

    test('servidor viejo (404) o respuesta vacía: null, sin error', () async {
      expect(await _repo(_Adapter(null)).fetch(), isNull);
      expect(await _repo(_Adapter(<String, dynamic>{})).fetch(), isNull);
    });

    test('sin conexión enseña la última que vio; si nunca la vio, null', () async {
      final a = _Adapter(_pet(points: 45));
      final repo = _repo(a);
      await repo.fetch();
      a.down = true;
      expect((await repo.fetch())?.points, 45);
      expect(await _repo(_Adapter(_pet(), down: true)).fetch(), isNull);
    });
  });

  group('Cerebro', () {
    final brain = PetBrain.instance;

    test('sale igual siempre y todas las zonas tienen neuronas', () {
      expect(brain.neurons.length, greaterThan(80));
      expect(identical(PetBrain.instance, brain), isTrue);
      for (final r in PetRegion.values) {
        expect(brain.neurons.where((n) => n.region == r), isNotEmpty, reason: r.name);
      }
      expect(brain.neurons.every((n) => n.order > 0 && n.order <= 1), isTrue);
      expect(brain.links, isNotEmpty);
    });

    test('apagado al nacer, encendido del todo al final y cada vez más por el camino', () {
      PetState at(double level) => PetState(skills: {for (final r in PetRegion.values) r: PetSkill(level: level)});
      expect(brain.litCount(const PetState()), 0);
      expect(brain.litCount(at(1)), brain.neurons.length);
      var before = 0;
      for (final level in [0.1, 0.3, 0.6, 0.9]) {
        final now = brain.litCount(at(level));
        expect(now, greaterThan(before));
        before = now;
      }
    });

    test('cada zona se enciende solo con lo suyo', () {
      final onlyWords = PetState(skills: {PetRegion.words: const PetSkill(level: 1)});
      final lit = brain.neurons.where((n) => n.lit(onlyWords.level(n.region)));
      expect(lit, isNotEmpty);
      expect(lit.every((n) => n.region == PetRegion.words), isTrue);
    });
  });

  group('Textos', () {
    tearDown(() => Lang.english = false);

    test('nombre de cada etapa; una etapa que la app no conoce sale como «Etapa N»', () {
      expect([for (var i = 0; i < 5; i++) petStageName(_full(i))], ['Chispa', 'Brote', 'Aprendiz', 'Voz', 'Mente brillante']);
      expect(petStageName(const PetState(stage: 5, stageKey: 'galaxy')), 'Etapa 6');
    });

    test('todo está también en inglés', () {
      Lang.english = true;
      Lang.onMissing = (key) => fail('falta en inglés: $key');
      addTearDown(() => Lang.onMissing = null);
      expect(petStageName(_full(0)), 'Spark');
      expect([for (final r in PetRegion.values) petSkillName(r)], ['Words it knows', 'Words it remembers well', 'Path units', 'Days in a row', 'Connections']);
      for (final key in ['Enséñale tu primera palabra', 'Ya sabe {0} palabras gracias a ti', 'Faltan {0} puntos para crecer', 'Su cerebro', 'Etapa {0} de {1}']) {
        expect(stringsEn.containsKey(key), isTrue, reason: key);
      }
    });
  });

  group('Pantalla', () {
    setUpAll(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
      await useTestFonts();
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    Widget app(Widget child, {PetState? pet, bool still = false}) => ProviderScope(
          overrides: [petProvider.overrideWith((ref) async => pet)],
          child: MaterialApp(
            theme: W.theme(),
            builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: still), child: c!),
            home: Scaffold(body: child),
          ),
        );

    testWidgets('la tarjeta dice la etapa y cuántas palabras sabe; se puede tocar', (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(PetCardView(pet: PetState.tryParse(_pet())!, onTap: () => taps++)));
      expect(find.text('Brainy · Brote'), findsOneWidget);
      expect(find.text('Ya sabe 15 palabras gracias a ti'), findsOneWidget);
      await tester.tap(find.byType(PetCardView));
      expect(taps, 1);

      await tester.pumpWidget(app(PetCardView(pet: PetState.tryParse(_pet(words: 1))!)));
      expect(find.text('Ya sabe 1 palabra gracias a ti'), findsOneWidget);
      await tester.pumpWidget(app(PetCardView(pet: PetState.tryParse(_pet(stage: 0, key: 'spark', words: 0, level: 0))!)));
      expect(find.text('Enséñale tu primera palabra'), findsOneWidget);
    });

    testWidgets('sin mascota (servidor viejo) la tarjeta no ocupa sitio', (tester) async {
      await tester.pumpWidget(app(const PetCard()));
      await tester.pump();
      expect(find.byType(PetCardView), findsNothing);
      expect(tester.getSize(find.byType(PetCard)), Size.zero);
    });

    testWidgets('con mascota, la tarjeta de Hoy sale', (tester) async {
      await tester.pumpWidget(app(const PetCard(), pet: PetState.tryParse(_pet())));
      await tester.pump();
      expect(find.byType(PetCardView), findsOneWidget);
      expect(Routes.pet, '/pet');
    });

    testWidgets('la pantalla: etapa, lo que falta para crecer y cada zona con su cuenta', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const PetPage(), pet: PetState.tryParse(_pet())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Brote'), findsOneWidget);
      expect(find.text('Etapa 2 de 5'), findsOneWidget);
      expect(find.text('Faltan 15 puntos para crecer'), findsOneWidget);
      expect(find.text('Palabras que conoce'), findsOneWidget);
      expect(find.text('15 / 300'), findsOneWidget);
      expect(find.text('2 / 12'), findsOneWidget);
      expect(find.textContaining('neuronas encendidas'), findsOneWidget);
      expect(find.text('Brainy siempre te espera: lo que ya sabe no se le olvida.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('última etapa: no pide más puntos', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const PetPage(), pet: PetState.tryParse(_pet(stage: 4, key: 'wise', points: 900, next: null, progress: 1))));
      await tester.pump();
      expect(find.text('Mente brillante'), findsOneWidget);
      expect(find.textContaining('para crecer'), findsNothing);
      expect(find.textContaining('última etapa'), findsOneWidget);
    });

    testWidgets('sin mascota la pantalla lo dice con calma', (tester) async {
      await tester.pumpWidget(app(const PetPage()));
      await tester.pump();
      expect(find.text('Brainy está descansando. Vuelve en un rato.'), findsOneWidget);
    });

    testWidgets('se dibuja en las 5 etapas, pequeña y grande, apagada y encendida, sin errores', (tester) async {
      for (var stage = 0; stage < 5; stage++) {
        for (final pet in [PetState(stage: stage), _full(stage)]) {
          for (final size in [72.0, 250.0]) {
            await tester.pumpWidget(app(Center(child: PetFigure(pet: pet, size: size))));
            await tester.pump(const Duration(milliseconds: 700));
            await tester.pump(const Duration(milliseconds: 2900)); // pasa por un parpadeo
            expect(tester.takeException(), isNull, reason: 'etapa $stage, tamaño $size');
            expect(tester.getSize(find.byType(PetFigure)), Size(size, size));
          }
        }
      }
    });

    testWidgets('con «Reducir movimiento» se queda quieta', (tester) async {
      await tester.pumpWidget(app(Center(child: PetFigure(pet: _full(3))), still: true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(app(Center(child: PetFigure(pet: _full(3)))));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'sin esa opción sí se mueve');
    });
  });
}
