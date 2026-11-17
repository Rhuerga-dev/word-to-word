import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/session_plan.dart';
import '../../data/session_repository.dart';
import 'exercise_outcome.dart';

enum ConvoPhase { loading, aiTurn, ready, listening, checking, grading, done, error }

/// Un mensaje del chat. [me] = lo dijo el alumno; debajo, su corrección si la hay.
class ConvoMsg {
  const ConvoMsg({required this.me, required this.text, this.feedback, this.fixes = const []});
  final bool me;
  final String text;
  final String? feedback;
  final List<(String said, String correct)> fixes;
}

class ConvoState {
  const ConvoState({
    this.phase = ConvoPhase.loading,
    this.messages = const [],
    this.sessionId,
    this.status = '',
    this.error = '',
    this.result,
  });

  final ConvoPhase phase;
  final List<ConvoMsg> messages;
  final int? sessionId;
  final String status, error;
  final UnitTestResult? result;

  /// Respuestas mínimas del alumno para poder evaluar (igual que el servidor).
  static const minTurns = 5;

  int get userTurns => messages.where((m) => m.me).length;
  bool get canFinish => userTurns >= minTurns;

  ConvoState copyWith({
    ConvoPhase? phase,
    List<ConvoMsg>? messages,
    int? sessionId,
    String? status,
    String? error,
    UnitTestResult? result,
  }) =>
      ConvoState(
        phase: phase ?? this.phase,
        messages: messages ?? this.messages,
        sessionId: sessionId ?? this.sessionId,
        status: status ?? this.status,
        error: error ?? this.error,
        result: result ?? this.result,
      );
}

/// Prueba de la unidad: una conversación hablada con la IA en la situación de la unidad.
/// Al terminar, la IA califica toda la charla y marca el paso de la unidad.
class ConversationController extends AutoDisposeFamilyNotifier<ConvoState, ConversationStep> {
  String get unitId => arg.unitId;
  String get scenario => arg.scenario;

  @override
  ConvoState build(ConversationStep step) => const ConvoState();

  SessionRepository get _repo => ref.read(sessionRepositoryProvider);
  AppAudio get _audio => ref.read(audioProvider);

  List<Map<String, String>> _history() => [for (final m in state.messages) {'role': m.me ? 'user' : 'assistant', 'content': m.text}];

  /// Pide el turno de la IA (corrige el último mensaje del alumno y responde). No reproduce el audio.
  Future<String> _converseStep() async {
    state = state.copyWith(phase: ConvoPhase.aiTurn, status: tr('Pensando…'));
    final turn = await _repo.converse(sessionId: state.sessionId!, scenario: scenario, messages: _history());
    final msgs = [...state.messages];
    final lastUser = msgs.lastIndexWhere((m) => m.me);
    if (lastUser >= 0 && (turn.feedback != null || turn.fixes.isNotEmpty)) {
      msgs[lastUser] = ConvoMsg(me: true, text: msgs[lastUser].text, feedback: turn.feedback, fixes: turn.fixes);
    }
    msgs.add(ConvoMsg(me: false, text: turn.reply));
    state = state.copyWith(messages: msgs, phase: ConvoPhase.ready, status: '');
    return turn.reply;
  }

  Future<int> _ensureSession() async {
    if (state.sessionId != null) return state.sessionId!;
    final id = await _repo.startConversation(scenario);
    state = state.copyWith(sessionId: id);
    return id;
  }

  /// Con el dedo: abre la conversación y la IA saluda.
  Future<void> startTap() async {
    if (state.sessionId != null) return;
    try {
      await _ensureSession();
      final reply = await _converseStep();
      await _audio.say(reply);
    } catch (e) {
      state = state.copyWith(phase: ConvoPhase.error, error: '$e');
    }
  }

  /// Vuelve a intentarlo tras un error (sin sesión aún).
  Future<void> retry() async {
    state = const ConvoState();
    await startTap();
  }

  /// Con el dedo: graba, lo pasa a texto y pide el siguiente turno de la IA.
  Future<void> listen() async {
    if (state.phase != ConvoPhase.ready) return;
    state = state.copyWith(phase: ConvoPhase.listening, status: tr('Te escucho…'));
    try {
      final r = await _audio.record(maxMs: 45000, silenceMs: 2500);
      if (!r.heard && !r.maybeVoice) {
        state = state.copyWith(phase: ConvoPhase.ready, status: tr('No te oí. Habla cuando quieras.'));
        return;
      }
      state = state.copyWith(phase: ConvoPhase.checking, status: tr('Entendiendo lo que dijiste…'));
      final text = await _repo.sendTurn(state.sessionId!, r.wav);
      if (text.trim().isEmpty) {
        state = state.copyWith(phase: ConvoPhase.ready, status: tr('No te entendí. Prueba otra vez.'));
        return;
      }
      state = state.copyWith(messages: [...state.messages, ConvoMsg(me: true, text: text)]);
      final reply = await _converseStep();
      await _audio.say(reply);
    } catch (e) {
      state = state.copyWith(phase: ConvoPhase.ready, status: '$e');
    }
  }

  void stopRecording() => _audio.stopRecording();

  /// Termina y evalúa toda la conversación (marca el paso de la unidad).
  Future<void> finish() async {
    if (state.phase == ConvoPhase.grading || state.phase == ConvoPhase.done) return;
    if (!state.canFinish) return;
    state = state.copyWith(phase: ConvoPhase.grading, status: '');
    try {
      final res = await _repo.unitTest(unitId, state.sessionId!, _history());
      try {
        await _repo.finishSpeaking(state.sessionId!);
      } catch (_) {}
      state = state.copyWith(phase: ConvoPhase.done, result: res);
    } catch (e) {
      state = state.copyWith(phase: ConvoPhase.ready, status: '$e');
    }
  }

  static final _stop = RegExp(r"\b(stop|finish|that'?s all|i'?m done|done|para|termina|terminar|basta)\b", caseSensitive: false);

  /// Manos libres: la IA habla, te oye y sigue sola; di «stop» (o pulsa Terminar) para evaluar.
  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    try {
      await _ensureSession();
      if (state.messages.isEmpty) {
        final reply = await _converseStep();
        await hf.say(reply);
      } else {
        await hf.say(state.messages.last.text);
      }
      while (state.userTurns < 10) {
        final h = await hf.listen(maxMs: 45000, silenceMs: 2500, transcribe: false);
        if (h.silent) {
          await hf.say('Say something whenever you are ready.');
          continue;
        }
        state = state.copyWith(phase: ConvoPhase.checking);
        final text = await _repo.sendTurn(state.sessionId!, h.wav!);
        if (text.trim().isEmpty) {
          await hf.say("I didn't catch that.");
          continue;
        }
        if (_stop.hasMatch(text) && state.canFinish) break;
        state = state.copyWith(messages: [...state.messages, ConvoMsg(me: true, text: text)]);
        final reply = await _converseStep();
        await hf.say(reply);
      }
      if (state.canFinish) {
        await hf.say('Let me check how you did.');
        await finish();
        final r = state.result;
        if (r != null) await hf.say(r.feedback, lang: ref.read(spanishProvider).coachVoice);
      } else {
        await hf.say('Talk a little more next time to finish the unit test.');
      }
    } catch (e) {
      state = state.copyWith(phase: ConvoPhase.ready, status: '$e');
    }
    return ExerciseOutcome.skipped;
  }
}

final conversationControllerProvider =
    NotifierProvider.autoDispose.family<ConversationController, ConvoState, ConversationStep>(ConversationController.new);
