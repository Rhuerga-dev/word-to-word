// Los cuidados de Brainy (Paso 6a+) y el Modo Brainy (6a++): datos, reglas, textos y pantallas.
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
import 'package:word_to_word/core/l10n/tr.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/services/audio_service.dart';
import 'package:word_to_word/core/services/brainy_mode_setting.dart';
import 'package:word_to_word/core/storage/offline_cache.dart';
import 'package:word_to_word/core/theme/app_theme.dart';
import 'package:word_to_word/features/auth/data/user_profile.dart';
import 'package:word_to_word/features/auth/presentation/auth_controller.dart';
import 'package:word_to_word/features/pet/data/pet.dart';
import 'package:word_to_word/features/pet/data/pet_repository.dart';
import 'package:word_to_word/features/pet/presentation/pet_actions.dart';
import 'package:word_to_word/features/pet/presentation/pet_card.dart';
import 'package:word_to_word/features/pet/presentation/pet_care_panel.dart';
import 'package:word_to_word/features/pet/presentation/pet_figure.dart';
import 'package:word_to_word/features/pet/presentation/pet_home.dart';
import 'package:word_to_word/features/pet/presentation/pet_page.dart';
import 'package:word_to_word/features/pet/presentation/pet_providers.dart';
import 'package:word_to_word/features/pet/presentation/pet_texts.dart';
import 'package:word_to_word/features/session/data/session_plan.dart';
import 'package:word_to_word/features/today/data/today.dart';

import 'support/test_fonts.dart';

const _moods = ['hibernating', 'asleep', 'sick', 'hungry', 'messy', 'bored', 'happy', 'ok'];

/// El bloque `care` de GET /api/pet (igual que tests/Feature/PetCareTest.php del servidor).
Map<String, dynamic> _care({int food = 2, int joy = 3, int clean = 4, int health = 4, String mood = 'ok', bool sick = false, String? form, String? leaning}) => {
      'needs': {
        'food': {'hearts': food, 'max': 4},
        'joy': {'hearts': joy, 'max': 4},
        'clean': {'hearts': clean, 'max': 4},
        'health': {'hearts': health, 'max': 4},
      },
      'mood': mood,
      'asleep': mood == 'asleep',
      'hibernating': mood == 'hibernating',
      'sick': sick,
      'mess': 7,
      'days': 3,
      'leaning': leaning,
      'form': form,
      'history': [
        {'stage': 'spark', 'at': '2026-11-10'},
        {'stage': 'sprout', 'at': '2026-11-18'},
      ],
    };

Map<String, dynamic> _pet({Map<String, dynamic>? care, int stage = 1, String key = 'sprout'}) => {
      'name': 'Brainy',
      'points': 45,
      'stage': {'index': stage, 'key': key, 'count': 5, 'from': 15, 'next': stage == 4 ? null : 60, 'progress': 0.667},
      'regions': {
        'words': {'count': 15, 'target': 300, 'level': 0.05},
        'memory': {'count': 5, 'target': 150, 'level': 0.033},
        'path': {'count': 2, 'target': 12, 'level': 0.167},
        'habit': {'count': 4, 'target': 30, 'level': 0.133},
        'links': {'level': 0.096},
      },
      if (care != null) 'care': care,
    };

PetState _state({String mood = 'ok', String? form, int stage = 1, bool sick = false, int food = 2}) =>
    PetState.tryParse(_pet(care: _care(mood: mood, form: form, sick: sick, food: food), stage: stage, key: const ['spark', 'sprout', 'curious', 'chatty', 'wise'][stage]))!;

/// Lo de hoy, con [n] cosas de cada tipo que se pidan.
TodayData _today({int news = 0, int reviews = 0, int ear = 0, int mistakes = 0, bool offline = false}) {
  Map<String, dynamic> card(int i) => {'id': i, 'word': 'w$i'};
  return TodayData.fromJson({
    'xp': {'xp': 0, 'goal': 100},
    'plan': {
      'new': [for (var i = 0; i < news; i++) card(i)],
      'reviews': [for (var i = 0; i < reviews; i++) card(100 + i)],
      'ear': [for (var i = 0; i < ear; i++) card(200 + i)],
      'mistakes': [for (var i = 0; i < mistakes; i++) {'id': i, 'said': 'a', 'correct': 'b'}],
      'sounds': [{'phoneme': 'θ'}],
    },
  }, offline: offline);
}

/// Responde a todo con [body]; null = 404 (servidor viejo); [down] = sin red. Apunta lo que se pidió.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.down = false});
  Object? body;
  bool down;
  final asked = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    asked.add('${o.method} ${o.uri.path}');
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
  final dir = Directory.systemTemp.createTempSync('w2w-petcare');
  return PetRepository(api, OfflineCache(api, dir: () async => dir));
}

// --- La app de verdad con los datos de la demo (como settings_tab_test.dart).
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

class _Mode extends BrainyModeSetting {
  _Mode(this.on);
  final bool on;
  @override
  Future<bool> build() async => on;
}

void main() {
  group('Datos', () {
    test('lee las barras, el ánimo, la forma y la historia', () {
      final c = PetState.tryParse(_pet(care: _care(food: 1, joy: 3, clean: 0, health: 2, mood: 'sick', sick: true, leaning: 'talker')))!.care!;
      expect([for (final n in PetNeed.values) c.of(n)], [1, 3, 0, 2]);
      expect((c.max, c.mood, c.sick, c.resting, c.mess, c.days), (4, 'sick', true, false, 7, 3));
      expect((c.leaning, c.form), ('talker', null));
      expect(c.history, [('spark', '2026-11-10'), ('sprout', '2026-11-18')]);
    });

    test('servidor sin cuidados: la mascota sale igual que antes, sin barras', () {
      final p = PetState.tryParse(_pet())!;
      expect(p.care, isNull);
      expect(p.points, 45);
      expect(PetCare.tryParse(null), isNull);
      expect(PetCare.tryParse('x'), isNull);
      expect(PetCare.tryParse(const <String, dynamic>{'mood': 'ok'}), isNull);
    });

    test('valores raros no rompen: los corazones se quedan entre 0 y el máximo', () {
      final c = PetCare.tryParse({
        'needs': {'food': {'hearts': 99, 'max': 4}, 'joy': {'hearts': -3}, 'clean': 'x'},
        'mood': 7,
        'history': 'nada',
      })!;
      expect((c.of(PetNeed.food), c.of(PetNeed.joy), c.of(PetNeed.clean), c.of(PetNeed.health)), (4, 0, 4, 4));
      expect(c.mood, '7');
      expect(c.history, isEmpty);
      expect(petMoodText(c), 'Brainy está bien.');
      expect(petBubble(c), isNull);
    });

    test('dormida o hibernando: descansa', () {
      expect(_state(mood: 'asleep').care!.resting, isTrue);
      expect(_state(mood: 'hibernating').care!.resting, isTrue);
      expect(_state(mood: 'hungry').care!.resting, isFalse);
    });
  });

  group('Botones de cuidado', () {
    test('el servidor dice qué ejercicio toca (POST /pet/accion)', () async {
      final a = _Adapter({'action': 'feed', 'go': 'new'});
      expect(await _repo(a).act(PetAction.feed), 'new');
      expect(a.asked, ['POST /api/pet/feed']);
      expect(await _repo(_Adapter({'action': 'clean', 'go': null})).act(PetAction.clean), '', reason: 'nada que hacer ahora');
    });

    test('sin red o con servidor viejo no falla: decide la app', () async {
      expect(await _repo(_Adapter(null)).act(PetAction.play), isNull);
      expect(await _repo(_Adapter({}, down: true)).act(PetAction.play), isNull);
      expect(await _repo(_Adapter({'message': 'ok'})).act(PetAction.play), isNull);
    });

    test('la regla de la app es la del servidor', () {
      expect(petLocalGo(PetAction.feed, _today(news: 2, reviews: 3)), 'new');
      expect(petLocalGo(PetAction.feed, _today(reviews: 3)), 'reviews');
      expect(petLocalGo(PetAction.feed, _today()), '');
      expect(petLocalGo(PetAction.play, _today(ear: 1)), 'ear');
      expect(petLocalGo(PetAction.play, _today()), 'sound');
      expect(petLocalGo(PetAction.clean, _today(reviews: 1, mistakes: 1)), 'reviews');
      expect(petLocalGo(PetAction.clean, _today(mistakes: 1)), 'mistakes');
      expect(petLocalGo(PetAction.clean, _today()), '');
      expect(petLocalGo(PetAction.medicine, _today()), 'sound');
    });

    test('cada cuidado abre los ejercicios de W2W de siempre', () {
      final d = _today(news: 2, reviews: 3, ear: 4, mistakes: 1);
      expect(petCarePlan('new', d)!.steps, everyElement(isA<NewStep>()));
      expect(petCarePlan('new', d)!.steps, hasLength(2));
      expect(petCarePlan('reviews', d)!.steps, allOf(hasLength(3), everyElement(isA<ReviewStep>())));
      expect(petCarePlan('ear', d)!.steps, allOf(hasLength(4), everyElement(isA<EarStep>())));
      expect(petCarePlan('mistakes', d)!.steps.single, isA<MistakeStep>());
      final sound = petCarePlan('sound', d, title: 'Medicina')!;
      expect(sound.steps, everyElement(isA<SoundStep>()));
      expect((sound.steps.first as SoundStep).phoneme, 'θ', reason: 'tu sonido más difícil');
      expect((sound.title, sound.daily), ('Medicina', false));
    });

    test('si no hay nada de eso (o algo desconocido), no abre nada', () {
      expect(petCarePlan('new', _today()), isNull);
      expect(petCarePlan('', _today(news: 1)), isNull);
      expect(petCarePlan('dance', _today(news: 1)), isNull);
    });

    test('sin conexión solo se pueden hacer las fichas', () {
      final d = _today(news: 1, reviews: 1, ear: 1, mistakes: 1, offline: true);
      expect(petCarePlan('new', d), isNotNull);
      expect(petCarePlan('reviews', d), isNotNull);
      expect(petCarePlan('ear', d), isNull);
      expect(petCarePlan('sound', d), isNull);
      expect(petCarePlan('mistakes', d), isNull);
    });
  });

  group('Textos', () {
    tearDown(() => Lang.english = false);

    test('cada estado tiene su frase; ninguna culpa ni dramatiza', () {
      final texts = [for (final m in _moods) petMoodText(_state(mood: m).care!)];
      expect(texts.toSet(), hasLength(_moods.length));
      for (final t in texts) {
        expect(t.toLowerCase(), isNot(anyOf(contains('culpa'), contains('muere'), contains('abandon'), contains('triste'))), reason: t);
      }
      expect(petBubble(_state(mood: 'hungry').care!), "I'm hungry!");
      expect(petBubble(_state(mood: 'ok').care!), isNull);
      expect([for (final a in PetAction.values) petActionName(a)], ['Comer', 'Jugar', 'Limpiar', 'Medicina']);
      expect([for (final f in ['talker', 'listener', 'scholar', 'balanced', 'dragon', null]) petFormName(f)], ['Parlanchina', 'Orejona', 'Sabia', 'Equilibrada', null, null]);
      expect(petStageKeyName('sprout'), 'Brote');
    });

    test('todo está también en inglés', () {
      Lang.english = true;
      Lang.onMissing = (key) => fail('falta en inglés: $key');
      addTearDown(() => Lang.onMissing = null);
      expect([for (final n in PetNeed.values) petNeedName(n)], ['Food', 'Mood', 'Cleanliness', 'Health']);
      expect([for (final a in PetAction.values) petActionName(a)], ['Feed', 'Play', 'Clean', 'Medicine']);
      for (final a in PetAction.values) {
        petActionHint(a);
        petNothingText(a);
      }
      for (final m in _moods) {
        petMoodText(_state(mood: m).care!);
      }
      expect(petFormName('listener'), 'Listener');
      for (final key in [
        'Modo Brainy',
        'La pantalla principal es Brainy, tu mascota: cuidarla es estudiar. Tu sesión y todo lo demás siguen a un toque.',
        'Mi sesión de hoy',
        'Ver su cerebro y su historia',
        'Cuidarla es estudiar: cada botón abre un ejercicio.',
        'Su historia',
        'La cuidaste {0} día',
        'La cuidaste {0} días',
        'Su forma adulta: {0}',
        'De adulta va para: {0}',
        'Su forma adulta depende de lo que más practiques: hablar, oír o palabras.',
        '{0} de {1}',
      ]) {
        expect(tr(key), isNot(key), reason: key);
      }
    });
  });

  group('Pantallas', () {
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
      PathProviderPlatform.instance = _TempPaths(Directory.systemTemp.createTempSync('w2w-petcare-app').path);
      await useTestFonts();
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 5200);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
    }

    Widget wrap(Widget child, {PetState? pet}) => ProviderScope(
          overrides: [petProvider.overrideWith((ref) async => pet)],
          child: MaterialApp(theme: W.theme(), home: Scaffold(body: child)),
        );

    int hearts(WidgetTester tester, PetNeed n) => tester.widget<PetHearts>(find.byKey(ValueKey('hearts-${n.name}'))).count;

    testWidgets('el panel: cómo está, cuatro barras de corazones y cuatro botones', (tester) async {
      final done = <PetAction>[];
      final care = PetCare.tryParse(_care(food: 1, joy: 3, clean: 0, health: 4, mood: 'hungry'))!;
      await tester.pumpWidget(wrap(SingleChildScrollView(child: PetCarePanel(care: care, onAction: (a) async => done.add(a)))));

      expect(find.text('Brainy tiene hambre de palabras.'), findsOneWidget);
      expect([for (final n in PetNeed.values) hearts(tester, n)], [1, 3, 0, 4]);
      for (final label in ['Comida', 'Ánimo', 'Limpieza', 'Salud', 'Comer', 'Jugar', 'Limpiar', 'Medicina', 'Palabras nuevas', 'Oído']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      for (final a in PetAction.values) {
        await tester.tap(find.byKey(ValueKey('pet-${a.name}')));
        await tester.pump();
      }
      expect(done, PetAction.values);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mientras abre un ejercicio, los botones no se pueden pulsar dos veces', (tester) async {
      var calls = 0;
      await tester.pumpWidget(wrap(SingleChildScrollView(
        child: PetCarePanel(care: _state().care!, onAction: (a) async {
          calls++;
          await Future<void>.delayed(const Duration(seconds: 1));
        }),
      )));
      await tester.tap(find.byKey(const ValueKey('pet-feed')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pet-play')), warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('pet-play')));
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 2);
    });

    testWidgets('la pantalla de Brainy enseña los cuidados y su historia', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(const PetPage(), pet: PetState.tryParse(_pet(care: _care(mood: 'bored', leaning: 'listener')))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PetCarePanel), findsOneWidget);
      expect(find.text('Brainy quiere jugar.'), findsOneWidget);
      expect(find.text("Let's play!"), findsOneWidget);
      expect(find.text('Su historia'), findsOneWidget);
      expect(find.text('La cuidaste 3 días'), findsOneWidget);
      expect(find.text('De adulta va para: Orejona'), findsOneWidget);
      expect(find.text('2026-11-18'), findsOneWidget);
      // Lo de antes sigue ahí.
      expect(find.text('Etapa 2 de 5'), findsOneWidget);
      expect(find.text('15 / 300'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con un servidor sin cuidados la pantalla queda como antes', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(const PetPage(), pet: PetState.tryParse(_pet())));
      await tester.pump();
      expect(find.byType(PetCarePanel), findsNothing);
      expect(find.byType(PetStory), findsNothing);
      expect(find.byKey(const ValueKey('pet-bubble')), findsNothing);
      expect(find.text('Etapa 2 de 5'), findsOneWidget);
    });

    testWidgets('al volver de un cuidado, Brainy da las gracias', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [petThanksProvider.overrideWith((ref) => PetAction.feed)],
        child: MaterialApp(home: Scaffold(body: Center(child: PetWithBubble(pet: _state(mood: 'hungry'))))),
      ));
      expect(find.text('Yum! Thank you!'), findsOneWidget);
      expect(find.text("I'm hungry!"), findsNothing);
    });

    testWidgets('se dibuja en todos los estados y formas adultas, sin errores', (tester) async {
      for (final mood in _moods) {
        for (final stage in [0, 2, 4]) {
          for (final form in [null, 'talker', 'listener', 'scholar', 'balanced', 'dragon']) {
            await tester.pumpWidget(wrap(Center(child: PetFigure(pet: _state(mood: mood, stage: stage, form: form), size: 200))));
            await tester.pump(const Duration(milliseconds: 700));
            await tester.pump(const Duration(milliseconds: 2900));
            expect(tester.takeException(), isNull, reason: '$mood, etapa $stage, forma $form');
          }
        }
      }
    });

    // ----- Modo Brainy: la app de verdad.
    Future<void> launch(WidgetTester tester, {required bool mode, PetState? pet}) async {
      tall(tester);
      final api = Api(dio: Dio(BaseOptions(baseUrl: 'https://test/api'))..httpClientAdapter = _Fixtures());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          authControllerProvider.overrideWith(_Signed.new),
          headphonesProvider.overrideWith((ref) => Stream.value(null)),
          petProvider.overrideWith((ref) async => pet),
          brainyModeProvider.overrideWith(() => _Mode(mode)),
        ],
        child: const WordToWordApp(),
      ));
      for (var i = 0; i < 14; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('Modo Brainy apagado (por defecto): Hoy es la pantalla de siempre', (tester) async {
      await launch(tester, mode: false, pet: _state(mood: 'hungry'));

      expect(find.byType(PetHome), findsNothing);
      expect(find.byType(PetCarePanel), findsNothing);
      expect(find.text('Empezar la sesión'), findsOneWidget);
      expect(find.text('Tus palabras'), findsOneWidget);
      expect(find.byType(PetCardView), findsOneWidget, reason: 'la tarjeta de Brainy sigue como estaba');
      expect(tester.takeException(), isNull);
    });

    testWidgets('el ajuste nace apagado', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(await c.read(brainyModeProvider.future), isFalse);
      await c.read(brainyModeProvider.notifier).set(true);
      expect(c.read(brainyModeProvider).value, isTrue);
    });

    testWidgets('Modo Brainy encendido: la pantalla principal es Brainy y lo de siempre sigue a un toque', (tester) async {
      await launch(tester, mode: true, pet: _state(mood: 'hungry', food: 1));

      expect(find.byType(PetHome), findsOneWidget);
      expect(find.text('Brainy tiene hambre de palabras.'), findsOneWidget);
      expect(find.text("I'm hungry!"), findsOneWidget);
      expect(hearts(tester, PetNeed.food), 1);
      expect(find.text('Empezar la sesión'), findsNothing);
      // Las pestañas de siempre siguen abajo.
      for (final tab in ['Camino', 'Practicar', 'Progreso', 'Ajustes']) {
        expect(find.text(tab), findsWidgets, reason: tab);
      }

      await tester.tap(find.byKey(const ValueKey('pet-home-session')));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Empezar la sesión'), findsOneWidget, reason: 'la sesión de siempre, a un toque');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Modo Brainy encendido pero sin mascota (servidor viejo o caído): sale Hoy de siempre', (tester) async {
      await launch(tester, mode: true);
      expect(find.byType(PetHome), findsNothing);
      expect(find.text('Empezar la sesión'), findsOneWidget);

      await launch(tester, mode: true, pet: PetState.tryParse(_pet()));   // mascota sin cuidados
      expect(find.byType(PetHome), findsNothing);
    });

    testWidgets('el interruptor está en Ajustes', (tester) async {
      await launch(tester, mode: false, pet: _state());
      await tester.tap(find.text('Ajustes').last);
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 300));
      }
      final sw = find.byKey(const ValueKey('brainy-mode-switch'));
      expect(sw, findsOneWidget);
      expect(tester.widget<SwitchListTile>(sw).value, isFalse);
      expect(find.text('Modo Brainy'), findsOneWidget);
    });
  });
}
