import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/hands_free.dart';
import '../../data/session_repository.dart';
import '../../data/word_card.dart';
import 'exercise_outcome.dart';

class ReviewState {
  const ReviewState({this.shown = false, this.busy = false, this.grade, this.error, this.xp = 0});
  final bool shown, busy;
  final String? grade, error;
  final int xp;

  bool get finished => grade != null;
  ExerciseOutcome get outcome => ExerciseOutcome(xp: xp, graded: true, ok: grade != 'again' && error == null);
}

/// Ficha de repaso: ver la respuesta y ponerse nota (con el dedo o con la voz).
class ReviewController extends AutoDisposeFamilyNotifier<ReviewState, WordCard> {
  WordCard get card => arg;

  @override
  ReviewState build(WordCard card) => const ReviewState();

  void reveal() => state = ReviewState(shown: true, busy: state.busy);

  Future<void> rate(String grade) async {
    state = const ReviewState(shown: true, busy: true);
    try {
      final xp = await ref.read(sessionRepositoryProvider).review(card.id, grade);
      state = ReviewState(shown: true, grade: grade, xp: xp);
    } catch (e) {
      state = ReviewState(shown: true, grade: grade, error: '$e');
    }
  }

  /// Por voz: la app pregunta, te deja contestar, dice la respuesta y te pide la nota.
  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    if (state.finished) return state.outcome;
    final question = card.englishOnly && card.definition != null ? '${card.definition}. What is the word?' : card.word;
    await hf.say(question);
    for (var i = 0; i < 3; i++) {
      if (!await handleCommand(hf, await hf.listen(), onHelp: () => hf.say(card.translation, lang: 'es'))) break;
    }
    reveal();
    if (card.englishOnly) await hf.say(card.word);
    await hf.say(card.translation, lang: 'es');
    for (var i = 0; i < 2; i++) {
      await hf.say(i == 0 ? 'Again, hard, good or easy?' : 'Say again, hard, good or easy.');
      final h = await hf.listen(maxMs: 4000, silenceMs: 900);
      if (await handleCommand(hf, h)) continue;
      final g = parseGrade(h.text);
      if (g != null) {
        await rate(g);
        return state.outcome;
      }
    }
    await rate('hard');
    return state.outcome;
  }
}

final reviewControllerProvider = NotifierProvider.autoDispose.family<ReviewController, ReviewState, WordCard>(ReviewController.new);
