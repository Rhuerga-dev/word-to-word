import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/network/api_client.dart';
import 'package:word_to_word/core/services/audio_service.dart';
import 'package:word_to_word/core/services/hands_free.dart';
import 'package:word_to_word/core/utils/word_drill.dart';
import 'package:word_to_word/core/widgets/mic_button.dart';
import 'package:word_to_word/core/widgets/word_drill_view.dart';
import 'package:word_to_word/features/session/data/session_repository.dart';
import 'package:word_to_word/features/session/data/word_card.dart';
import 'package:word_to_word/features/session/presentation/exercises/mistake_controller.dart';
import 'package:word_to_word/features/session/presentation/exercises/mistake_exercise.dart';

/// Audio de mentira: habla al instante y «te oye» siempre.
class _FakeAudio extends AppAudio {
  _FakeAudio() : super(Api());
  final said = <String>[];
  @override
  Future<void> say(String text, {String lang = 'en', bool slow = false}) async => said.add(text);
  @override
  Future<void> stopVoice() async {}
  @override
  void stopRecording() {}
  @override
  Future<Recording> record({int maxMs = 6000, int silenceMs = 1200, void Function()? onVoice}) async =>
      Recording(Uint8List.fromList([1, 2, 3]), true, 900);
}

/// Servidor de mentira: devuelve las notas en orden y apunta qué se evaluó.
class _FakeRepo implements SessionRepository {
  _FakeRepo(this.scores);
  final List<int> scores;
  final assessed = <String>[];
  @override
  Future<int> assess(String word, String? phoneme, Uint8List wav) async {
    assessed.add(word);
    return scores.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _plan = DrillPlan(word: 'thirty', chunk: 'thirty years', sentence: 'I am thirty years old', phonemes: ['θ']);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final ch in ['plugins.it_nomads.com/flutter_secure_storage', 'com.llfbandit.record/messages', 'com.ryanheise.just_audio.methods']) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
  }

  group('qué palabra practicar', () {
    const sentence = 'I am thirty years old';

    test('elige la peor palabra que además no se entendió', () {
      final p = pickDrill(const [
        WeakWord('years', accuracy: 50, error: 'Mispronunciation'),
        WeakWord('thirty', accuracy: 20, error: 'Mispronunciation'),
      ], sentence, 'I am dirty years old');
      expect(p?.word, 'thirty');
      expect(p?.chunk, 'thirty years');
    });

    test('si se entendió (acento), no para aunque Azure ponga nota baja', () {
      expect(pickDrill(const [WeakWord('thirty', accuracy: 30)], sentence, 'I am thirty years old'), isNull);
    });

    test('con nota de 60 o más no para', () {
      expect(pickDrill(const [WeakWord('thirty', accuracy: 65)], sentence, 'I am dirty years old'), isNull);
    });

    test('una palabra que faltó (Omission) sí se practica', () {
      expect(pickDrill(const [WeakWord('old', accuracy: 0, error: 'Omission')], sentence, 'I am thirty years')?.word, 'old');
    });

    test('ni números ni frases de una palabra', () {
      expect(pickDrill(const [WeakWord('30', accuracy: 10)], 'I am 30 years old', 'I am years old'), isNull);
      expect(pickDrill(const [WeakWord('three', accuracy: 10)], 'three', 'tree'), isNull);
    });

    test('el trozo de frase', () {
      expect(chunkFor(sentence, 'old'), 'years old');          // la última: con la anterior
      expect(chunkFor('Go to it', 'it'), 'Go to it');          // la anterior es corta: una más
      expect(chunkFor('I want to go home', 'want'), 'want to go'); // "to" es corta: se junta una más
      expect(chunkFor('I am 30 years old', 'am'), 'am');        // con números, la palabra sola
    });
  });

  testWidgets('mini-taller: la palabra sola → su trozo → la frase completa', (tester) async {
    final audio = _FakeAudio(), repo = _FakeRepo([82, 40, 45]);
    var done = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [audioProvider.overrideWithValue(audio), sessionRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: Scaffold(body: WordDrillView(plan: _plan, onDone: () => done = true))),
    ));
    await tester.pump();
    expect(find.text('Practiquemos una palabra'), findsOneWidget);
    expect(find.text('thirty'), findsWidgets);
    expect(audio.said, ['thirty']);                        // la dice despacio al empezar

    await tester.tap(find.byType(MicButton));              // 82: sale bien → pasa al trozo
    await tester.pumpAndSettle();
    expect(find.text('2. En su trozo de frase'), findsOneWidget);
    expect(find.byKey(const ValueKey('drill-text')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('drill-text'))).data, 'thirty years');

    await tester.tap(find.byType(MicButton));              // 40: otra vez
    await tester.pumpAndSettle();
    expect(find.text('40/100 — escucha y otra vez'), findsOneWidget);
    await tester.tap(find.byType(MicButton));              // 45: segundo intento → sigue igual, sin atascarse
    await tester.pumpAndSettle();
    expect(find.text('3. Ahora la frase completa'), findsOneWidget);
    expect(repo.assessed, ['thirty', 'thirty years', 'thirty years']);

    await tester.tap(find.byKey(const ValueKey('drill-continue')));
    expect(done, isTrue);
  });

  testWidgets('errores para repasar: con una palabra fallada se abre el mini-taller', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        audioProvider.overrideWithValue(_FakeAudio()),
        mistakeControllerProvider.overrideWith(() => _FixedMistake(const MistakeState(drill: _plan, drillDone: true))),
      ],
      child: MaterialApp(home: Scaffold(body: MistakeExercise(mistake: const Mistake(id: 1, said: 'I have thirty years', correct: 'I am thirty years old'), onDone: (_) {}))),
    ));
    await tester.pump();
    expect(find.byType(WordDrillView), findsOneWidget);
  });

  test('manos libres: el mini-taller por voz', () async {
    final audio = _FakeAudio(), repo = _FakeRepo([30, 75, 90]);
    final c = ProviderContainer(overrides: [audioProvider.overrideWithValue(audio)]);
    addTearDown(c.dispose);
    final hf = c.read(handsFreeProvider.notifier);
    await hf.setOn(true);
    await hf.runAs(hf.begin(), () => wordDrillHandsFree(hf, repo, _plan, spanish: false));
    expect(repo.assessed, ['thirty', 'thirty', 'thirty years']);
    expect(audio.said.first, "Let's practice one word.");
    expect(audio.said, containsAllInOrder(['Say: thirty.', 'Again: thirty.', 'Good!', 'Say: thirty years.', 'Good!', 'Now the whole sentence.']));
  });
}

class _FixedMistake extends MistakeController {
  _FixedMistake(this.fixed);
  final MistakeState fixed;
  @override
  MistakeState build(Mistake mistake) => fixed;
}
