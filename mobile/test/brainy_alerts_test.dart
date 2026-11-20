// Avisos de Brainy: la mascota avisa cuando va a tener hambre o va a querer jugar, solo en Modo Brainy.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/services/brainy_alerts.dart';
import 'package:word_to_word/core/services/brainy_mode_setting.dart';
import 'package:word_to_word/core/services/reminder_service.dart';
import 'package:word_to_word/features/pet/data/pet.dart';
import 'package:word_to_word/features/pet/presentation/pet_providers.dart';

class _Mode extends BrainyModeSetting {
  _Mode(this.on);
  final bool on;
  @override
  Future<bool> build() async => on;
}

class _Wanted extends BrainyAlertsSetting {
  _Wanted(this.stored);
  String? stored;
  @override
  Future<String?> readStored() async => stored;
  @override
  Future<void> writeStored(String value) async => stored = value;
}

/// Apunta lo que se le pide programar, sin tocar el teléfono.
class _Service extends ReminderService {
  final calls = <List<BrainyAlert>>[];
  @override
  Future<void> syncBrainy(List<BrainyAlert> alerts) async => calls.add(alerts);
}

PetState _pet({String name = 'Luna', List<Map<String, String>>? alerts}) => PetState.tryParse({
  'name': name,
  'stage': {'index': 1, 'key': 'sprout', 'count': 5},
  'regions': <String, dynamic>{},
  'care': {
    'needs': {for (final n in ['food', 'joy', 'clean', 'health']) n: {'hearts': 3, 'max': 4}},
    'mood': 'ok',
    'alerts': alerts ?? [],
  },
})!;

void main() {
  final now = DateTime(2026, 11, 20, 10, 0);
  DateTime at(int day, int hour, [int minute = 0]) => DateTime(2026, 11, day, hour, minute);

  group('qué avisos se programan', () {
    test('uno por cosa, con el nombre de la mascota y sin culpar', () {
      final plan = BrainyAlerts.plan(now, [('bored', at(20, 19)), ('hungry', at(20, 14))], 'Luna');

      expect(plan.map((a) => a.at), [at(20, 14), at(20, 19)], reason: 'en orden de hora');
      expect(plan.first.title, 'Luna tiene hambre');
      expect(plan.last.title, 'Luna quiere jugar');
      for (final a in plan) {
        final all = '${a.title} ${a.body}'.toLowerCase();
        for (final bad in ['perd', 'culpa', 'olvid', 'abandon', 'triste', 'sola', 'no has', 'todavía']) {
          expect(all.contains(bad), isFalse, reason: 'sin culpa: «$bad» en «$all»');
        }
      }
    });

    test('nunca de noche: lo que cae tarde o de madrugada pasa a las 8:30', () {
      final plan = BrainyAlerts.plan(now, [('hungry', at(20, 21, 30)), ('bored', at(22, 6))], 'Luna');
      expect(plan.map((a) => a.at), [at(21, 8, 30), at(22, 8, 30)]);
      for (final a in plan) {
        expect(a.at.hour >= BrainyAlerts.quietTo && a.at.hour < BrainyAlerts.quietFrom, isTrue);
      }
    });

    test('lo que ya pasó no se avisa, y dos muy seguidos se quedan en uno', () {
      expect(BrainyAlerts.plan(now, [('hungry', at(20, 9))], 'Luna'), isEmpty);
      final close = BrainyAlerts.plan(now, [('hungry', at(20, 14)), ('bored', at(20, 15))], 'Luna');
      expect(close.map((a) => a.title), ['Luna tiene hambre']);
    });

    test('como mucho 2, y una clave que la app no conoce se ignora', () {
      final plan = BrainyAlerts.plan(
          now, [('hungry', at(20, 12)), ('dragon', at(20, 13)), ('bored', at(20, 16)), ('hungry', at(21, 12))], '');
      expect(plan.length, BrainyAlerts.max);
      expect(plan.first.title, 'Brainy tiene hambre', reason: 'sin nombre: Brainy');
    });
  });

  test('el servidor dice cuándo; un servidor viejo (sin «alerts») no rompe nada', () {
    final pet = _pet(alerts: [
      {'kind': 'hungry', 'at': '2026-11-20T19:00:00Z'},
      {'kind': 'bored', 'at': 'no es una fecha'},
    ]);
    expect(pet.care!.alerts, [('hungry', DateTime.utc(2026, 11, 20, 19))]);
    final old = PetState.tryParse({
      'name': 'Luna',
      'stage': {'index': 0, 'key': 'spark', 'count': 5},
      'regions': <String, dynamic>{},
      'care': {'needs': {'food': {'hearts': 3, 'max': 4}}},
    })!;
    expect(old.care!.alerts, isEmpty);
  });

  group('cuándo se programan', () {
    final soon = DateTime.now().add(const Duration(days: 2));
    final noon = DateTime(soon.year, soon.month, soon.day, 12).toUtc().toIso8601String();

    Future<_Service> run({required bool mode, String? stored, PetState? pet}) async {
      final service = _Service();
      final c = ProviderContainer(overrides: [
        brainyModeProvider.overrideWith(() => _Mode(mode)),
        brainyAlertsProvider.overrideWith(() => _Wanted(stored)),
        petProvider.overrideWith((ref) async => pet),
        reminderServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(c.dispose);
      c.listen(brainyAlertsSyncProvider, (_, __) {});
      await c.read(brainyModeProvider.future);
      await c.read(brainyAlertsProvider.future);
      await c.read(petProvider.future);
      c.read(brainyAlertsSyncProvider);
      return service;
    }

    final pet = _pet(alerts: [{'kind': 'hungry', 'at': noon}]);

    test('en Modo Brainy se programan', () async {
      final s = await run(mode: true, pet: pet);
      expect(s.calls.last.map((a) => a.title), ['Luna tiene hambre']);
    });

    test('sin Modo Brainy se quitan', () async {
      final s = await run(mode: false, pet: pet);
      expect(s.calls.last, isEmpty);
    });

    test('con el ajuste apagado se quitan', () async {
      final s = await run(mode: true, stored: '0', pet: pet);
      expect(s.calls.last, isEmpty);
    });

    test('sin mascota (servidor viejo) se quitan', () async {
      final s = await run(mode: true, pet: null);
      expect(s.calls.last, isEmpty);
    });
  });

  test('el ajuste nace encendido y recuerda lo que eliges', () async {
    final c = ProviderContainer(overrides: [brainyAlertsProvider.overrideWith(() => _Wanted(null))]);
    addTearDown(c.dispose);
    expect(await c.read(brainyAlertsProvider.future), isTrue);
    await c.read(brainyAlertsProvider.notifier).set(false);
    expect(c.read(brainyAlertsProvider).value, isFalse);
    expect((c.read(brainyAlertsProvider.notifier) as _Wanted).stored, '0');
  });
}
