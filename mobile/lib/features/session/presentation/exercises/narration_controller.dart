import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/hands_free.dart';
import '../../data/session_repository.dart';
import 'exercise_outcome.dart';
import '../../../../core/l10n/tr.dart';
import '../../../auth/presentation/auth_controller.dart';

enum NarrationPhase { loading, ready, recording, waiting, done, error }

class NarrationState {
  const NarrationState({this.phase = NarrationPhase.loading, this.topic, this.feedback, this.said = '', this.error = ''});
  final NarrationPhase phase;
  final NarrationTopic? topic;
  final NarrationFeedback? feedback;
  final String said, error;

  bool get finished => phase == NarrationPhase.done;

  NarrationState copyWith({NarrationPhase? phase, NarrationTopic? topic, NarrationFeedback? feedback, String? said, String? error}) => NarrationState(
      phase: phase ?? this.phase, topic: topic ?? this.topic, feedback: feedback ?? this.feedback, said: said ?? this.said, error: error ?? this.error);
}

/// Narración del día: un minuto hablando sin parar sobre un tema y luego la corrección.
class NarrationController extends AutoDisposeNotifier<NarrationState> {
  @override
  NarrationState build() {
    Future.microtask(create);
    return const NarrationState();
  }

  SessionRepository get _repo => ref.read(sessionRepositoryProvider);

  Future<void> create() async {
    if (state.topic != null) return;
    try {
      state = state.copyWith(phase: NarrationPhase.ready, topic: await _repo.startNarration());
    } catch (e) {
      state = state.copyWith(phase: NarrationPhase.error, error: '$e');
    }
  }

  void _fail(Object e) => state = state.copyWith(phase: NarrationPhase.error, error: '$e');

  /// Sube lo grabado y trae la corrección.
  Future<void> _process(Uint8List wav, {int? reactionMs}) async {
    final topic = state.topic!;
    state = state.copyWith(phase: NarrationPhase.waiting);
    final text = await _repo.sendTurn(topic.sessionId, wav, reactionMs: reactionMs);
    if (text.isEmpty) throw ApiException(tr('No se entendió lo que dijiste. Prueba otra vez, un poco más alto.'));
    final fb = await _repo.narration(topic.sessionId, text);
    await _repo.finishSpeaking(topic.sessionId);
    state = state.copyWith(phase: NarrationPhase.done, feedback: fb, said: text);
  }

  /// Con el dedo.
  Future<void> go() async {
    final audio = ref.read(audioProvider), topic = state.topic;
    if (topic == null) return create();
    try {
      await audio.say(topic.en);
      if (ref.read(spanishProvider).hideTranslation) {
        await audio.say('Talk for one minute. Start now.');
      } else {
        await audio.say('Habla un minuto. Empieza ya.', lang: 'es');
      }
      state = state.copyWith(phase: NarrationPhase.recording);
      final t0 = DateTime.now();
      int? reaction;
      final r = await audio.record(maxMs: 58000, silenceMs: 4000, onVoice: () => reaction = DateTime.now().difference(t0).inMilliseconds);
      if (!r.heard && !r.maybeVoice) throw ApiException(tr('No te oí. Acércate al micrófono y prueba otra vez.'));
      await _process(r.wav, reactionMs: reaction);
      if (state.feedback?.comment != null) await audio.say(state.feedback!.comment!, lang: ref.read(spanishProvider).coachVoice);
    } catch (e) {
      _fail(e);
    }
  }

  void stop() => ref.read(audioProvider).stopRecording();

  Future<ExerciseOutcome> handsFree(HandsFreeController hf) async {
    if (state.finished) return ExerciseOutcome.skipped;
    await create();
    final topic = state.topic;
    if (topic == null) return ExerciseOutcome.skipped;
    await hf.say(topic.en);
    await hf.say('Talk for one minute. Start now.');
    for (var i = 0; i < 2; i++) {
      state = state.copyWith(phase: NarrationPhase.recording);
      final h = await hf.listen(maxMs: 58000, silenceMs: 4000, transcribe: false);
      if (h.silent) {
        await hf.say("I didn't hear you. Let's try again. Start now.");
        continue;
      }
      try {
        await _process(h.wav!);
      } catch (e) {
        _fail(e);
        await hf.say("I couldn't understand that. Let's move on.");
        return ExerciseOutcome.skipped;
      }
      final fb = state.feedback!;
      if (fb.comment != null) await hf.say(fb.comment!, lang: ref.read(spanishProvider).coachVoice);
      if (fb.better != null) {
        await hf.say('A more natural way:');
        await hf.say(fb.better!);
      }
      return ExerciseOutcome.skipped;
    }
    state = state.copyWith(phase: NarrationPhase.ready);
    return ExerciseOutcome.skipped;
  }
}

final narrationControllerProvider = NotifierProvider.autoDispose<NarrationController, NarrationState>(NarrationController.new);
