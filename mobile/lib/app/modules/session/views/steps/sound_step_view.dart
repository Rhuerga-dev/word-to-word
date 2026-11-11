import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/providers/api_client.dart';
import '../../../../data/services/audio_service.dart';
import '../../../../global_widgets/feedback_bar.dart';
import '../../../../global_widgets/mic_button.dart';
import '../../../../global_widgets/step_page.dart';

// ---------- Sonido débil ----------
class SoundStepView extends StatefulWidget {
  const SoundStepView({super.key, required this.phoneme, required this.word, required this.onNext});
  final String phoneme, word;
  final VoidCallback onNext;
  @override
  State<SoundStepView> createState() => _SoundStepViewState();
}

class _SoundStepViewState extends State<SoundStepView> {
  bool _rec = false;
  int _tries = 0;
  int? _pct;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    Get.find<AppAudio>().say(widget.word, slow: true);
  }

  Future<void> _say() async {
    final audio = Get.find<AppAudio>(), api = Get.find<Api>();
    setState(() {
      _rec = true;
      _msg = '';
    });
    try {
      final r = await audio.record(maxMs: 3500, silenceMs: 700);
      if (!r.heard) {
        _msg = 'No te oí. Habla un poco más cerca.';
      } else {
        final res = await api.upload('/pronunciation/assess', r.wav, fields: {'text': widget.word, 'phoneme': widget.phoneme});
        _pct = ((res['target_score'] ?? res['score']) as num).toInt();
        _tries++;
        if (_pct! < 80 && _tries < 3) {
          _msg = 'Sonido al $_pct%: escúchala otra vez y exagera el movimiento.';
          audio.say(widget.word, slow: true);
        }
      }
    } catch (e) {
      _msg = e.toString();
    }
    if (mounted) setState(() => _rec = false);
  }

  @override
  Widget build(BuildContext context) {
    final done = _pct != null && (_pct! >= 80 || _tries >= 3);
    return StepPage(
      bottom: done
          ? FeedbackBar(ok: _pct! >= 80, title: _pct! >= 80 ? '¡Bien dicho!' : 'Sigue practicándolo', detail: '/${widget.phoneme}/ al $_pct%', onNext: widget.onNext)
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MicButton(recording: _rec, onPressed: _rec ? null : _say),
                const SizedBox(height: 10),
                const Text('Toca y dila en voz alta', style: TextStyle(color: W.muted)),
              ]),
            ),
      children: [
        stepKind('Pronunciación · /${widget.phoneme}/'),
        Row(children: [
          Flexible(child: Text(widget.word, style: W.display(46))),
          IconButton(tooltip: 'Escuchar', icon: const Icon(Icons.volume_up), onPressed: () => Get.find<AppAudio>().say(widget.word, slow: true)),
        ]),
        const SizedBox(height: 10),
        if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: W.warn)),
      ],
    );
  }
}
