import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/services/audio_service.dart';
import 'package:word_to_word/core/services/hands_free.dart';
import 'package:word_to_word/core/widgets/hands_free_bar.dart';

/// Manos libres con la fase fija (sin micrófono ni voz de verdad).
class _FixedHandsFree extends HandsFreeController {
  _FixedHandsFree(this.phase);
  final HfPhase phase;
  var finished = 0;

  @override
  HandsFreeState build() => HandsFreeState(on: true, phase: phase);

  @override
  void finishListening() => finished++;
}

Future<void> _pump(WidgetTester tester, HfPhase phase) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      handsFreeProvider.overrideWith(() => _FixedHandsFree(phase)),
      headphonesProvider.overrideWith((ref) => Stream.value('AirPods')),
    ],
    child: const MaterialApp(home: Scaffold(bottomNavigationBar: HandsFreeBar())),
  ));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('mientras piensa, manos libres muestra el loader de W2W', (tester) async {
    await _pump(tester, HfPhase.thinking);
    expect(find.byKey(const ValueKey('w2w-loader')), findsOneWidget);
    expect(find.text('Pensando…'), findsOneWidget);
  });

  testWidgets('mientras escucha, no hay loader sino el micrófono', (tester) async {
    await _pump(tester, HfPhase.listening);
    expect(find.byKey(const ValueKey('w2w-loader')), findsNothing);
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('mientras escucha, tocar el círculo termina sin esperar el silencio', (tester) async {
    final hf = _FixedHandsFree(HfPhase.listening);
    await tester.pumpWidget(ProviderScope(
      overrides: [handsFreeProvider.overrideWith(() => hf), headphonesProvider.overrideWith((ref) => Stream.value('AirPods'))],
      child: const MaterialApp(home: Scaffold(bottomNavigationBar: HandsFreeBar())),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('hf-finish')));
    expect(hf.finished, 1);
  });
}
