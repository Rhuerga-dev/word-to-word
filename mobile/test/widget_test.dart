import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/routing/app_router.dart';
import 'package:word_to_word/core/routing/routes.dart';
import 'package:word_to_word/core/services/hands_free.dart';
import 'package:word_to_word/core/services/reminder_service.dart';
import 'package:word_to_word/core/storage/offline_cache.dart';
import 'package:word_to_word/core/utils/format.dart';
import 'package:word_to_word/features/path/data/path_models.dart';
import 'package:word_to_word/features/session/data/session_plan.dart';
import 'package:word_to_word/features/session/data/word_card.dart';
import 'package:word_to_word/features/session/presentation/exercises/exercise_outcome.dart';
import 'package:word_to_word/features/session/presentation/session_controller.dart';
import 'package:word_to_word/features/today/data/today.dart';

void main() {
  test('plainExample quita asteriscos o deja un hueco', () {
    expect(plainExample('I *think* so'), 'I think so');
    expect(plainExample('I *think* so', cloze: true), 'I _____ so');
    expect(plainExample(null), '');
  });

  test('days', () {
    expect(days(1), 'mañana');
    expect(days(3), 'en 3 días');
  });

  test('soundKey normaliza fonemas', () {
    expect(soundKey('r'), 'ɹ');
    expect(soundKey('iː'), 'i');
    expect(soundKey('ɝ'), 'ɜ');
    expect(soundKey('k'), isNull);
  });

  test('errorMessage toma el primer error de validación', () {
    expect(Api.errorMessage({'message': 'x', 'errors': {'email': ['Correo inválido']}}, 422), 'Correo inválido');
    expect(Api.errorMessage(null, 500), 'Error 500');
  });

  test('WordCard aguanta campos que faltan o vienen con otro tipo', () {
    final c = WordCard.fromJson({'id': '7', 'word': 'deadline', 'mode': 'new', 'previews': {'good': 3}});
    expect(c.id, 7);
    expect(c.translation, '');
    expect(c.isNew, isTrue);
    expect(c.previews['good'], 3);
    expect(c.example, isNull);
  });

  test('SessionPlan.fromToday ordena los pasos', () {
    final today = TodayData.fromJson({
      'xp': {'xp': 0, 'goal': 100, 'week': [{'xp': 10}, {'xp': 5}]},
      'streak': 3,
      'plan': {
        'reviews': [{'id': 1, 'word': 'a', 'mode': 'review'}],
        'new': [{'id': 2, 'word': 'b', 'mode': 'new'}],
        'sounds': [{'phoneme': 'θ'}],
        'mistakes': [{'id': 9, 'said': 'x', 'correct': 'y'}],
      },
    });
    expect(today.xp.weekTotal, 15);
    expect(today.studied, isFalse);
    final plan = SessionPlan.fromToday(today);
    expect(plan.daily, isTrue);
    expect(plan.steps.map((s) => s.runtimeType.toString()).toList(), ['ReviewStep', 'NewStep', 'SoundStep', 'SoundStep', 'NarrateStep', 'MistakeStep']);
  });

  test('Camino: siguiente paso de la unidad', () {
    final u = PathUnit.fromJson({'id': 'u3', 'number': 3, 'title': 'Freelance', 'state': 'open', 'steps': {'words': true, 'sound': true}});
    expect(u.state, UnitState.open);
    expect(u.stepsDone, 2);
    expect(u.nextStep, 'shadow');
  });

  test('router: sin sesión al login; con sesión fuera del login', () {
    expect(authRedirect(loading: true, loggedIn: false, location: Routes.today), Routes.splash);
    expect(authRedirect(loading: false, loggedIn: false, location: Routes.today), Routes.login);
    expect(authRedirect(loading: false, loggedIn: false, location: Routes.login), isNull);
    expect(authRedirect(loading: false, loggedIn: true, location: Routes.login), Routes.today);
    expect(authRedirect(loading: false, loggedIn: true, location: Routes.splash), Routes.today);
    expect(authRedirect(loading: false, loggedIn: true, location: Routes.progress), isNull);
  });

  test('recordatorio: hoy solo si no estudiaste y la hora no pasó', () {
    final now = DateTime(2026, 11, 10, 12, 0);
    final pending = ReminderService.nextTimes(now, '19:30', false);
    expect(pending.length, ReminderService.days);
    expect(pending.first, DateTime(2026, 11, 10, 19, 30));
    expect(ReminderService.nextTimes(now, '19:30', true).first, DateTime(2026, 11, 11, 19, 30));
    expect(ReminderService.nextTimes(now, '08:00', false).first, DateTime(2026, 11, 11, 8, 0));
  });

  test('órdenes de voz: solo cuando dices la orden sola', () {
    expect(parseCommand('Repeat.'), VoiceCommand.repeat);
    expect(parseCommand('slower please'), VoiceCommand.slower);
    expect(parseCommand('Next!'), VoiceCommand.next);
    expect(parseCommand('stop'), VoiceCommand.stop);
    expect(parseCommand('I need to stop working at five'), isNull);
    expect(parseCommand(''), isNull);
  });

  test('nota de la ficha por voz', () {
    expect(parseGrade('Good.'), 'good');
    expect(parseGrade('It was easy'), 'easy');
    expect(parseGrade('hard'), 'hard');
    expect(parseGrade('again'), 'again');
    expect(parseGrade('banana'), isNull);
    // Lo que el reconocedor suele escribir y la nota en español.
    expect(parseGrade('Heart.'), 'hard');
    expect(parseGrade('Could.'), 'good');
    expect(parseGrade('Easily'), 'easy');
    expect(parseGrade('Fácil'), 'easy');
    expect(parseGrade('difícil'), 'hard');
    expect(parseGrade('Bien'), 'good');
    expect(parseGrade('otra vez'), 'again');
  });

  test('sin conexión: devuelve lo guardado y encola las fichas', () async {
    final dir = await Directory.systemTemp.createTemp('w2w');
    final offline = <bool>[];
    final cache = OfflineCache(Api(baseUrl: 'http://127.0.0.1:9'), dir: () async => dir, onOffline: offline.add);
    expect(await cache.fetch('k', () async => {'n': 1}, (j, fromCache) => '${(j as Map)['n']}$fromCache'), '1false');
    expect(await cache.fetch('k', () async => throw ApiException('sin red'), (j, fromCache) => '${(j as Map)['n']}$fromCache'), '1true');
    expect(offline, [false, true]);
    await expectLater(cache.fetch('otro', () async => throw ApiException('sin red'), (j, _) => j), throwsA(isA<ApiException>()));
    await expectLater(cache.fetch('k', () async => throw ApiException('No', 422), (j, _) => j), throwsA(isA<ApiException>()));
    await cache.enqueue('/words/1/review', {'grade': 'good'});
    await cache.enqueue('/words/2/learn', null);
    expect((await cache.pending()).map((e) => e['path']), ['/words/1/review', '/words/2/learn']);
    expect(await cache.flush(), 0); // sigue sin red: no se pierde nada
    expect((await cache.pending()).length, 2);
    await dir.delete(recursive: true);
  });

  test('la sesión suma puntos y aciertos y termina', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final plan = SessionPlan(const [NarrateStep(), NarrateStep()], title: 'x');
    final sub = c.listen(sessionControllerProvider(plan), (_, __) {});
    final ctl = c.read(sessionControllerProvider(plan).notifier);
    ctl.done(const ExerciseOutcome(xp: 5, graded: true, ok: true));
    expect(sub.read().index, 1);
    ctl.done(const ExerciseOutcome(xp: 3, graded: true, ok: false));
    await Future<void>.delayed(Duration.zero);
    final s = sub.read();
    expect(s.ending, isTrue);
    expect(s.xp, 8);
    expect((s.graded, s.right), (2, 1));
    expect(s.result, isNotNull);
  });
}
