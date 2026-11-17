import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/widgets/mic_button.dart';
import 'package:word_to_word/features/session/data/session_plan.dart';
import 'package:word_to_word/features/session/data/session_repository.dart';
import 'package:word_to_word/features/session/presentation/exercises/conversation_controller.dart';
import 'package:word_to_word/features/session/presentation/exercises/conversation_exercise.dart';

/// Conversación con el estado fijo (sin micrófono, sin servidor y sin arranque automático).
class _Fixed extends ConversationController {
  _Fixed(this.fixed);
  final ConvoState fixed;

  @override
  ConvoState build(ConversationStep step) => fixed;

  @override
  Future<void> startTap() async {} // el initState no debe llamar al servidor en el test
}

const _step = ConversationStep(unitId: 'a1-hello', scenario: 'neighbor', scenarioTitle: 'Charla con un vecino');

List<ConvoMsg> _msgs(int userTurns) => [
      for (var i = 0; i < userTurns; i++) ...[
        const ConvoMsg(me: false, text: 'How are you?'),
        ConvoMsg(me: true, text: 'I am fine $i'),
      ],
    ];

Future<void> _pump(WidgetTester tester, ConvoState s) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [conversationControllerProvider.overrideWith(() => _Fixed(s))],
    child: MaterialApp(home: Scaffold(body: ConversationExercise(step: _step, onDone: (_) {}))),
  ));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('la cabecera muestra la situación de la unidad', (tester) async {
    await _pump(tester, ConvoState(phase: ConvoPhase.ready, sessionId: 1, messages: _msgs(1)));
    expect(find.textContaining('Charla con un vecino'), findsOneWidget);
  });

  testWidgets('con pocas respuestas pide hablar más y no deja evaluar', (tester) async {
    await _pump(tester, ConvoState(phase: ConvoPhase.ready, sessionId: 1, messages: _msgs(2)));
    expect(find.byType(MicButton), findsOneWidget);
    expect(find.textContaining('Habla al menos 5 veces'), findsOneWidget);
    expect(find.text('Terminar y evaluar'), findsNothing);
  });

  testWidgets('con 5 respuestas aparece «Terminar y evaluar»', (tester) async {
    await _pump(tester, ConvoState(phase: ConvoPhase.ready, sessionId: 1, messages: _msgs(5)));
    expect(find.text('Terminar y evaluar'), findsOneWidget);
  });

  testWidgets('mientras califica: loader «Calificando tu conversación…»', (tester) async {
    await _pump(tester, ConvoState(phase: ConvoPhase.grading, sessionId: 1, messages: _msgs(5)));
    expect(find.byKey(const ValueKey('w2w-loader')), findsOneWidget);
    expect(find.text('Calificando tu conversación…'), findsOneWidget);
  });

  testWidgets('al aprobar: nota, mensaje y continuar', (tester) async {
    await _pump(
      tester,
      ConvoState(
        phase: ConvoPhase.done,
        sessionId: 1,
        messages: _msgs(1), // pocas burbujas para que la tarjeta de resultado quede visible en el test
        result: const UnitTestResult(passed: true, score: 8, feedback: 'Te hiciste entender muy bien.'),
      ),
    );
    expect(find.text('¡Aprobaste la unidad!'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('Te hiciste entender muy bien.'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('mientras grabas: botón para terminar de hablar', (tester) async {
    await _pump(tester, ConvoState(phase: ConvoPhase.listening, sessionId: 1, messages: _msgs(1)));
    expect(find.text('Terminé de hablar'), findsOneWidget);
  });
}
