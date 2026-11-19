// Android · Ajustes → «Micrófono de los audífonos»: apagado por defecto y sin verse activado si no hay audífonos.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/services/audio_service.dart';
import 'package:word_to_word/features/settings/presentation/settings_page.dart';

/// La preferencia guardada, de mentira: recuerda lo que se le pide sin tocar el audio del teléfono.
class _Pref extends HeadsetMicNotifier {
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
      headsetMicProvider.overrideWith(() => notifier),
      headphonesProvider.overrideWith((ref) => headphones),
    ],
    child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: HeadsetMicCard()))),
  ));
  await tester.pump();
  await tester.pump();
  return notifier;
}

SwitchListTile _tile(WidgetTester tester) => tester.widget<SwitchListTile>(find.byKey(const ValueKey('headset-mic-switch')));

void main() {
  test('nace apagado: solo graba por los audífonos si se encendió, y solo en Android', () {
    expect(AppAudio.headsetMicFrom(null, android: true), isFalse, reason: 'por defecto graba el teléfono, como siempre');
    expect(AppAudio.headsetMicFrom('0', android: true), isFalse);
    expect(AppAudio.headsetMicFrom('1', android: true), isTrue);
    expect(AppAudio.headsetMicFrom('1', android: false), isFalse, reason: 'el iPhone tiene su propia opción');
    expect(AppAudio.headsetMicFrom('basura', android: true), isFalse);
  });

  testWidgets('con audífonos y apagado: explica qué hace y se puede encender', (tester) async {
    final pref = await _show(tester, pref: false, headphones: Stream.value('Pixel Buds'));

    expect(_tile(tester).value, isFalse);
    expect(find.textContaining('Te oye por el micrófono del teléfono'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(pref.asked, [true]);
    expect(_tile(tester).value, isTrue);
    expect(find.textContaining('suena como una llamada'), findsOneWidget, reason: 'avisa de lo que se pierde');
  });

  testWidgets('sin audífonos: sale apagado y en gris aunque la preferencia esté encendida', (tester) async {
    final pref = await _show(tester, pref: true, headphones: Stream.value(null));

    expect(_tile(tester).value, isFalse);
    expect(_tile(tester).onChanged, isNull);
    expect(find.textContaining('No hay audífonos conectados'), findsOneWidget);

    await tester.tap(find.byType(Switch), warnIfMissed: false);
    await tester.pump();
    expect(pref.asked, isEmpty);
    expect(pref.on, isTrue, reason: 'la preferencia guardada no se toca');
  });

  testWidgets('al conectar los audífonos vuelve a verse la preferencia', (tester) async {
    late void Function(String?) plug;
    final stream = Stream<String?>.multi((c) {
      c.add(null);
      plug = c.add;
    });
    await _show(tester, pref: true, headphones: stream);
    expect(_tile(tester).value, isFalse);

    plug('Galaxy Buds');
    await tester.pump();
    await tester.pump();
    expect(_tile(tester).value, isTrue);
    expect(_tile(tester).onChanged, isNotNull);
  });
}
