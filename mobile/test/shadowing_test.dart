import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/widgets/mic_button.dart';
import 'package:word_to_word/features/session/data/session_plan.dart';
import 'package:word_to_word/features/session/data/session_repository.dart';
import 'package:word_to_word/features/session/presentation/exercises/shadowing_controller.dart';
import 'package:word_to_word/features/session/presentation/exercises/shadowing_exercise.dart';

/// Shadowing con el estado fijo (sin micrófono ni servidor).
class _Fixed extends ShadowingController {
  _Fixed(this.fixed);
  final ShadowState fixed;

  @override
  ShadowState build(ShadowStep step) => fixed;
}

const _step = ShadowStep(unitId: 'u1');

Future<void> _pump(WidgetTester tester, ShadowState s) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [shadowingControllerProvider.overrideWith(() => _Fixed(s))],
    child: MaterialApp(home: Scaffold(body: ShadowingExercise(step: _step, onDone: (_) {}))),
  ));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('cargando: solo el loader, sin micrófono', (tester) async {
    await _pump(tester, const ShadowState(phase: ShadowPhase.loading));
    expect(find.byKey(const ValueKey('w2w-loader')), findsOneWidget);
    expect(find.byType(MicButton), findsNothing);
  });

  testWidgets('mientras el servidor puntúa: loader «Evaluando…»', (tester) async {
    await _pump(tester, const ShadowState(phase: ShadowPhase.checking, title: 'Hi', sentences: ['Hello there']));
    expect(find.byKey(const ValueKey('w2w-loader')), findsOneWidget);
    expect(find.text('Evaluando tu pronunciación…'), findsOneWidget);
  });

  testWidgets('resultado: palabras en verde/rojo, nota y botón para pasar', (tester) async {
    await _pump(
      tester,
      const ShadowState(
        phase: ShadowPhase.result,
        title: 'Hi',
        sentences: ['Hello there'],
        index: 0,
        tries: 1,
        scores: [90],
        result: ShadowingScore(ok: true, score: 90, fluency: 88, accuracy: 92, words: [('Hello', true), ('there', false)]),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('there'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('pronunciación'), findsOneWidget);
    expect(find.text('¡Muy bien! Sonó natural.'), findsOneWidget);
    // Es la única frase: el botón dice «Terminar».
    expect(find.text('Terminar'), findsOneWidget);
  });

  testWidgets('no se entendió: avisa y no deja pasar todavía', (tester) async {
    await _pump(
      tester,
      const ShadowState(
        phase: ShadowPhase.result,
        sentences: ['Hello there'],
        result: ShadowingScore(ok: false, score: 0, fluency: 0, accuracy: 0, words: []),
      ),
    );
    expect(find.text('No te entendí bien. Acércate al micrófono y repítela.'), findsOneWidget);
    expect(find.byType(MicButton), findsOneWidget); // sigue pidiendo repetir
    expect(find.text('Terminar'), findsNothing);
  });

  testWidgets('al terminar: promedio y paso de la unidad completado', (tester) async {
    await _pump(
      tester,
      const ShadowState(
        phase: ShadowPhase.done,
        sentences: ['a', 'b'],
        scores: [80, 90],
        unitMsg: '✓ Shadowing de la unidad completado.',
      ),
    );
    expect(find.text('¡Terminaste! Promedio: 85%'), findsOneWidget);
    expect(find.text('✓ Shadowing de la unidad completado.'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });
}
