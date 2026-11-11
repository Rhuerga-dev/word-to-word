import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/hands_free.dart';
import '../../../../core/utils/format.dart';
import '../../data/session_repository.dart';
import '../../data/word_card.dart';
import 'exercise_outcome.dart';
import '../../../auth/presentation/auth_controller.dart';

class NewWordState {
  const NewWordState({this.saved, this.busy = false, this.xp = 0});

  /// null = aún no; true = guardada; false = no se pudo guardar.
  final bool? saved;
  final bool busy;
  final int xp;

  bool get finished => saved != null;
  ExerciseOutcome get outcome => ExerciseOutcome(xp: xp);
}

/// Palabra nueva: escucharla, decirla y marcarla como aprendida.
class NewWordController extends AutoDisposeFamilyNotifier<NewWordState, WordCard> {
  WordCard get card => arg;

  @override
  NewWordState build(WordCard card) => const NewWordState();

  Future<void> learn() async {
    state = const NewWordState(busy: true);
    try {
      state = NewWordState(saved: true, xp: await ref.read(sessionRepositoryProvider).learn(card.id));
    } catch (_) {
      state = const NewWordState(saved: false);
    }
  }

  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    if (state.finished) return state.outcome;
    await hf.say(card.word);
    // Escalera de español: la traducción solo en el escalón 1; después, la definición en inglés.
    if (ref.read(spanishProvider).step == 1) {
      await hf.say(card.translation, lang: 'es');
    } else if (card.definition != null) {
      await hf.say('It means: ${card.definition}');
    }
    if (card.example != null) await hf.say(plainExample(card.example));
    await hf.say('Now you. Say ${card.word} twice.');
    // Solo pasa cuando la dices: si no te oye, te la vuelve a pedir (y a la segunda se pausa).
    while (true) {
      final h = await hf.listen(maxMs: 5000);
      if (h.silent) {
        await hf.say('Your turn. Say ${card.word}.');
        continue;
      }
      if (!await handleCommand(hf, h, onHelp: () => hf.say(card.word, slow: true))) break;
    }
    await learn();
    return state.outcome;
  }
}

final newWordControllerProvider = NotifierProvider.autoDispose.family<NewWordController, NewWordState, WordCard>(NewWordController.new);
