import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/providers/api_client.dart';
import '../../../../data/services/audio_service.dart';
import '../../../../global_widgets/step_page.dart';

// ---------- Narración del día ----------
class NarrateStepView extends StatefulWidget {
  const NarrateStepView({super.key, required this.onNext});
  final VoidCallback onNext;
  @override
  State<NarrateStepView> createState() => _NarrateStepViewState();
}

class _NarrateStepViewState extends State<NarrateStepView> {
  Map? _topic;
  int? _session;
  String _phase = 'loading'; // loading · ready · rec · wait · done · error
  String _error = '';
  Map? _fb;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    try {
      final r = await Get.find<Api>().post('/speaking/sessions', {'scenario': 'narrate'});
      _topic = r['topic'] as Map;
      _session = (r['id'] as num).toInt();
      _phase = 'ready';
    } catch (e) {
      _phase = 'error';
      _error = e.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> _go() async {
    final audio = Get.find<AppAudio>(), api = Get.find<Api>();
    await audio.say(_topic!['en'] as String);
    await audio.say('Habla un minuto. Empieza ya.', lang: 'es');
    setState(() => _phase = 'rec');
    final t0 = DateTime.now();
    int? reaction;
    try {
      final r = await audio.record(maxMs: 58000, silenceMs: 4000, onVoice: () => reaction = DateTime.now().difference(t0).inMilliseconds);
      if (!r.heard) throw ApiException('No te oí. Acércate al micrófono y prueba otra vez.');
      if (mounted) setState(() => _phase = 'wait');
      final turn = await api.upload('/speaking/sessions/$_session/turns', r.wav, fields: {if (reaction != null) 'reaction_ms': '$reaction'});
      _text = (turn['text'] as String?) ?? '';
      if (_text.isEmpty) throw ApiException('No se entendió lo que dijiste. Prueba otra vez, un poco más alto.');
      _fb = await api.post('/speaking/sessions/$_session/narration', {'text': _text}) as Map;
      await api.post('/speaking/sessions/$_session/finish');
      _phase = 'done';
      if (mounted) setState(() {});
      if (_fb?['comment'] != null) await audio.say(_fb!['comment'] as String);
    } catch (e) {
      _phase = 'error';
      _error = e.toString();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = Get.find<AppAudio>();
    final children = <Widget>[
      stepKind('Narración del día · 1 minuto'),
      if (_topic != null) ...[
        Text(_topic!['en'] as String, style: W.display(24, weight: FontWeight.w600)),
        Text(_topic!['es'] as String, style: const TextStyle(color: W.muted)),
        const SizedBox(height: 14),
      ],
      if (_phase == 'loading') const Center(child: CircularProgressIndicator()),
      if (_phase == 'ready') const Text('Hablas un minuto sin parar, sin preparar nada. Si te quedas en blanco, describe lo que ves y sigue.'),
      if (_phase == 'rec') const Text('Te escucho… habla sin parar, aunque te equivoques.', style: TextStyle(color: W.bad, fontWeight: FontWeight.w700)),
      if (_phase == 'wait') const Text('Revisando lo que dijiste…'),
      if (_phase == 'error') Text(_error, style: const TextStyle(color: W.bad)),
      if (_phase == 'done' && _fb != null) ...[
        if (_fb!['comment'] != null) Text(_fb!['comment'] as String, style: const TextStyle(fontSize: 17)),
        if (_fb!['better'] != null) ...[
          const SizedBox(height: 14),
          Text('Así sonaría más natural', style: W.display(18)),
          const SizedBox(height: 6),
          Text(_fb!['better'] as String, style: const TextStyle(fontSize: 17, height: 1.5)),
          TextButton.icon(onPressed: () => audio.say(_fb!['better'] as String), icon: const Icon(Icons.volume_up), label: const Text('Escuchar')),
        ],
        for (final f in (_fb!['mistakes'] as List? ?? const []))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${f['said']}', style: const TextStyle(decoration: TextDecoration.lineThrough, color: W.bad)),
              const TextSpan(text: '  →  '),
              TextSpan(text: '${f['correct']}', style: const TextStyle(color: W.good, fontWeight: FontWeight.w700)),
            ])),
          ),
      ],
    ];
    final bottom = switch (_phase) {
      'ready' => bottomPad(FilledButton.icon(onPressed: _go, icon: const Icon(Icons.mic), label: const Text('Empezar'))),
      'rec' => bottomPad(FilledButton(onPressed: audio.stopRecording, child: const Text('Terminé'))),
      'done' => bottomPad(FilledButton(onPressed: widget.onNext, child: const Text('Continuar'))),
      'error' => bottomPad(Row(children: [
          Expanded(child: OutlinedButton(onPressed: widget.onNext, child: const Text('Saltar'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: _session == null ? _create : _go, child: const Text('Otra vez'))),
        ])),
      _ => null,
    };
    return StepPage(bottom: bottom, children: children);
  }
}
