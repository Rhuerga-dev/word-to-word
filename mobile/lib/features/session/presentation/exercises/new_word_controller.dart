import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/hands_free.dart';
import '../../../../core/utils/format.dart';
import '../../data/session_repository.dart';
import '../../data/word_card.dart';
import 'exercise_outcome.dart';

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
    await hf.say(card.translation, lang: 'es');
    if (card.example != null) await hf.say(plainExample(card.example));
    await hf.say('Now you. Say ${card.word} twice.');
    for (var i = 0; i < 3; i++) {
      if (!await handleCommand(hf, await hf.listen(maxMs: 5000), onHelp: () => hf.say(card.word, slow: true))) break;
    }
    await learn();
    return state.outcome;
  }
}

final newWordControllerProvider = NotifierProvider.autoDispose.family<NewWordController, NewWordState, WordCard>(NewWordController.new);
