import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/step_page.dart';
import '../../data/session_repository.dart';

enum _Phase { loading, ready, recording, waiting, done, error }

/// Narración del día: un minuto hablando sin parar sobre un tema; luego la corrección.
class NarrationExercise extends ConsumerStatefulWidget {
  const NarrationExercise({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  ConsumerState<NarrationExercise> createState() => _NarrationExerciseState();
}

class _NarrationExerciseState extends ConsumerState<NarrationExercise> {
  NarrationTopic? _topic;
  NarrationFeedback? _fb;
  _Phase _phase = _Phase.loading;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    try {
      _topic = await ref.read(sessionRepositoryProvider).startNarration();
      _phase = _Phase.ready;
    } catch (e) {
      _phase = _Phase.error;
      _error = e.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> _go() async {
    final audio = ref.read(audioProvider), repo = ref.read(sessionRepositoryProvider), topic = _topic!;
    await audio.say(topic.en);
    await audio.say('Habla un minuto. Empieza ya.', lang: 'es');
    setState(() => _phase = _Phase.recording);
    final t0 = DateTime.now();
    int? reaction;
    try {
      final r = await audio.record(maxMs: 58000, silenceMs: 4000, onVoice: () => reaction = DateTime.now().difference(t0).inMilliseconds);
      if (!r.heard) throw ApiException('No te oí. Acércate al micrófono y prueba otra vez.');
      if (mounted) setState(() => _phase = _Phase.waiting);
      final text = await repo.sendTurn(topic.sessionId, r.wav, reactionMs: reaction);
      if (text.isEmpty) throw ApiException('No se entendió lo que dijiste. Prueba otra vez, un poco más alto.');
      _fb = await repo.narration(topic.sessionId, text);
      await repo.finishSpeaking(topic.sessionId);
      _phase = _Phase.done;
      if (mounted) setState(() {});
      if (_fb!.comment != null) await audio.say(_fb!.comment!);
    } catch (e) {
      _phase = _Phase.error;
      _error = e.toString();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.read(audioProvider), fb = _fb;
    final children = <Widget>[
      stepKind('Narración del día · 1 minuto'),
      if (_topic != null) ...[
        Text(_topic!.en, style: W.display(24, weight: FontWeight.w600)),
        Text(_topic!.es, style: const TextStyle(color: W.muted)),
        const SizedBox(height: 14),
      ],
      switch (_phase) {
        _Phase.loading => const Center(child: CircularProgressIndicator()),
        _Phase.ready => const Text('Hablas un minuto sin parar, sin preparar nada. Si te quedas en blanco, describe lo que ves y sigue.'),
        _Phase.recording => const Text('Te escucho… habla sin parar, aunque te equivoques.', style: TextStyle(color: W.bad, fontWeight: FontWeight.w700)),
        _Phase.waiting => const Text('Revisando lo que dijiste…'),
        _Phase.error => Text(_error, style: const TextStyle(color: W.bad)),
        _Phase.done => const SizedBox.shrink(),
      },
      if (_phase == _Phase.done && fb != null) ...[
        if (fb.comment != null) Text(fb.comment!, style: const TextStyle(fontSize: 17)),
        if (fb.better != null) ...[
          const SizedBox(height: 14),
          Text('Así sonaría más natural', style: W.display(18)),
          const SizedBox(height: 6),
          Text(fb.better!, style: const TextStyle(fontSize: 17, height: 1.5)),
          TextButton.icon(onPressed: () => audio.say(fb.better!), icon: const Icon(Icons.volume_up), label: const Text('Escuchar')),
        ],
        for (final (said, correct) in fb.fixes)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: said, style: const TextStyle(decoration: TextDecoration.lineThrough, color: W.bad)),
              const TextSpan(text: '  →  '),
              TextSpan(text: correct, style: const TextStyle(color: W.good, fontWeight: FontWeight.w700)),
            ])),
          ),
      ],
    ];
    final bottom = switch (_phase) {
      _Phase.ready => bottomPad(FilledButton.icon(onPressed: _go, icon: const Icon(Icons.mic), label: const Text('Empezar'))),
      _Phase.recording => bottomPad(FilledButton(onPressed: audio.stopRecording, child: const Text('Terminé'))),
      _Phase.done => bottomPad(FilledButton(onPressed: widget.onNext, child: const Text('Continuar'))),
      _Phase.error => bottomPad(Row(children: [
          Expanded(child: OutlinedButton(onPressed: widget.onNext, child: const Text('Saltar'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: _topic == null ? _create : _go, child: const Text('Otra vez'))),
        ])),
      _ => null,
    };
    return StepPage(bottom: bottom, children: children);
  }
}
