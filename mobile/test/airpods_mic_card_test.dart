// Ajustes → «Micrófono de los AirPods» (iPhone): sin audífonos conectados no debe verse activado.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/services/audio_service.dart';
import 'package:word_to_word/features/settings/presentation/settings_page.dart';

/// La preferencia guardada, de mentira: recuerda lo que se le pide sin tocar el audio del teléfono.
class _Pref extends AirPodsMicNotifier {
  _Pref(this.on);
  bool on;
  final asked = <bool>[];
  @override
  Future<bool> build() async => on;
  @override
  Future<void> set(bool v) async {
    asked.add(v);
    state = AsyncData(on = v);
  }
}

Future<_Pref> _show(WidgetTester tester, {required bool pref, required Stream<String?> headphones}) async {
  final notifier = _Pref(pref);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      airPodsMicProvider.overrideWith(() => notifier),
      headphonesProvider.overrideWith((ref) => headphones),
    ],
    child: const MaterialApp(home: Scaffold(body: AirPodsMicCard())),
  ));
  await tester.pump();
  await tester.pump();
  return notifier;
}

SwitchListTile _tile(WidgetTester tester) => tester.widget<SwitchListTile>(find.byKey(const ValueKey('airpods-mic-switch')));

void main() {
  testWidgets('sin audífonos: sale apagado y en gris aunque la preferencia esté encendida', (tester) async {
    final pref = await _show(tester, pref: true, headphones: Stream.value(null));

    expect(_tile(tester).value, isFalse);
    expect(_tile(tester).onChanged, isNull, reason: 'en gris: no hay nada que activar ahora');
    expect(find.textContaining('No hay audífonos conectados'), findsOneWidget);
    expect(find.textContaining('Te oye por los AirPods'), findsNothing);

    await tester.tap(find.byType(Switch), warnIfMissed: false);
    await tester.pump();
    expect(pref.asked, isEmpty);
    expect(pref.on, isTrue, reason: 'la preferencia guardada no se toca');
  });

  testWidgets('sin audífonos y con la preferencia apagada: también lo dice', (tester) async {
    await _show(tester, pref: false, headphones: Stream.value(null));
    expect(_tile(tester).value, isFalse);
    expect(find.text('No hay audífonos conectados: te oye el micrófono del iPhone.'), findsOneWidget);
  });

  testWidgets('con audífonos: enseña la preferencia y se puede cambiar', (tester) async {
    final pref = await _show(tester, pref: true, headphones: Stream.value('AirPods Pro'));

    expect(_tile(tester).value, isTrue);
    expect(find.textContaining('Te oye por los AirPods'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(pref.asked, [false]);
    expect(_tile(tester).value, isFalse);
    expect(find.textContaining('Te oye por el micrófono del iPhone'), findsOneWidget);
  });

  testWidgets('al conectar los audífonos vuelve a verse la preferencia', (tester) async {
    late void Function(String?) plug;
    final stream = Stream<String?>.multi((c) {
      c.add(null);
      plug = c.add;
    });
    await _show(tester, pref: true, headphones: stream);
    expect(_tile(tester).value, isFalse);

    plug('AirPods Pro');
    await tester.pump();
    await tester.pump();
    expect(_tile(tester).value, isTrue);
    expect(_tile(tester).onChanged, isNotNull);
  });

  testWidgets('mientras no se sabe si hay audífonos, enseña la preferencia', (tester) async {
    await _show(tester, pref: true, headphones: const Stream<String?>.empty());
    expect(_tile(tester).value, isTrue);
    expect(_tile(tester).onChanged, isNotNull);
  });
}
