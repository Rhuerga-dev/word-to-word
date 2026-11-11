import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/hands_free.dart';
import '../../data/session_repository.dart';
import '../../data/word_card.dart';
import 'exercise_outcome.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/aid_box.dart';

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

  int get _step => ref.read(spanishProvider).step;

  /// "help": en el escalón 1 la traducción; después, una pista en inglés (definición o ejemplo).
  Future<void> _help(HandsFreeController hf) async {
    final aid = aidOf(card);
    if (aid != null && aid.isNotEmpty) return hf.say(aid, lang: 'es');
    if (_step == 1) return hf.say(card.translation, lang: 'es');
    final hint = card.englishOnly ? card.example : (card.definition ?? card.example);
    if (hint != null) await hf.say(plainExample(hint, cloze: card.englishOnly));
  }

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
    // Espera tu respuesta: si no te oye, te lo vuelve a pedir (y a la segunda se pausa, sin avanzar).
    while (true) {
      final h = await hf.listen();
      if (h.silent) {
        await hf.say('Take your time. Say the answer, or say help.');
        continue;
      }
      if (!await handleCommand(hf, h, onHelp: () => _help(hf))) break;
    }
    reveal();
    if (card.englishOnly) await hf.say(card.word);
    // Escalera de español: desde el escalón 2 la respuesta se dice en inglés (definición), sin traducir.
    if (_step == 1) {
      await hf.say(card.translation, lang: 'es');
    } else if (!card.englishOnly && card.definition != null) {
      await hf.say('It means: ${card.definition}');
    } else if (card.example != null) {
      await hf.say(plainExample(card.example));
    }
    // La nota solo la pones tú: sin respuesta no se califica.
    for (var i = 0;; i++) {
      await hf.say(i == 0 ? 'Again, hard, good or easy?' : 'Say again, hard, good or easy.');
      final h = await hf.listen(maxMs: 5000, silenceMs: 900);
      if (h.silent || await handleCommand(hf, h)) continue;
      final g = parseGrade(h.text);
      if (g != null) {
        await rate(g);
        final aid = aidOf(card);
        if (g == 'again' && aid != null && aid.isNotEmpty) await hf.say(aid, lang: 'es');
        return state.outcome;
      }
    }
  }
}

final reviewControllerProvider = NotifierProvider.autoDispose.family<ReviewController, ReviewState, WordCard>(ReviewController.new);
