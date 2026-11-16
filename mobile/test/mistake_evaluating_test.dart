import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/widgets/mic_button.dart';
import 'package:word_to_word/features/session/data/word_card.dart';
import 'package:word_to_word/features/session/presentation/exercises/mistake_controller.dart';
import 'package:word_to_word/features/session/presentation/exercises/mistake_exercise.dart';

/// Errores para repasar con el estado fijo (sin micrófono ni servidor).
class _Fixed extends MistakeController {
  _Fixed(this.fixed);
  final MistakeState fixed;

  @override
  MistakeState build(Mistake mistake) => fixed;
}

const _m = Mistake(id: 1, said: 'I have 30 years', correct: 'I am 30 years old');

Future<void> _pump(WidgetTester tester, MistakeState s) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [mistakeControllerProvider.overrideWith(() => _Fixed(s))],
    child: MaterialApp(home: Scaffold(body: MistakeExercise(mistake: _m, onDone: (_) {}))),
  ));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('mientras el servidor evalúa, loader en el centro con «Evaluando…»', (tester) async {
    await _pump(tester, const MistakeState(checking: true));
    expect(find.byKey(const ValueKey('mistake-evaluating')), findsOneWidget);
    expect(find.byKey(const ValueKey('w2w-loader')), findsOneWidget);
    expect(find.text('Evaluando tu pronunciación…'), findsOneWidget);
  });

  testWidgets('mientras prepara los consejos, el loader lo dice', (tester) async {
    await _pump(tester, const MistakeState(loadingTips: true));
    expect(find.byKey(const ValueKey('mistake-evaluating')), findsOneWidget);
    expect(find.text('Preparando cómo decirlo mejor…'), findsOneWidget);
  });

  testWidgets('sin esperar al servidor no hay velo', (tester) async {
    await _pump(tester, const MistakeState());
    expect(find.byKey(const ValueKey('mistake-evaluating')), findsNothing);
    expect(find.text('Dilo bien en voz alta'), findsOneWidget);
  });

  testWidgets('antes de hablar ya muestra la frase que hay que decir', (tester) async {
    await _pump(tester, const MistakeState());
    expect(find.text('I have 30 years'), findsOneWidget);      // lo que dijiste mal
    expect(find.text('Dilo así:'), findsOneWidget);
    expect(find.text('I am 30 years old'), findsOneWidget);    // lo que hay que repetir
  });

  testWidgets('mientras graba, el micro sigue activo para terminar sin esperar el silencio', (tester) async {
    await _pump(tester, const MistakeState(recording: true));
    expect(find.text('Te escucho… toca al terminar'), findsOneWidget);
    final ink = tester.widget<InkWell>(find.descendant(of: find.byType(MicButton), matching: find.byType(InkWell)));
    expect(ink.onTap, isNotNull);
  });
}
