import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/providers/api_client.dart';
import '../../../../data/services/audio_service.dart';
import '../../../../global_widgets/feedback_bar.dart';
import '../../../../global_widgets/mic_button.dart';
import '../../../../global_widgets/step_page.dart';

// ---------- Error para repasar ----------
class MistakeStepView extends StatefulWidget {
  const MistakeStepView({super.key, required this.mistake, required this.onXp, required this.onNext});
  final Map mistake;
  final void Function(num?) onXp;
  final VoidCallback onNext;
  @override
  State<MistakeStepView> createState() => _MistakeStepViewState();
}

class _MistakeStepViewState extends State<MistakeStepView> {
  bool _rec = false;
  Map? _r;
  String _msg = '';
  int _tries = 0;

  Future<void> _say() async {
    final audio = Get.find<AppAudio>(), api = Get.find<Api>();
    setState(() {
      _rec = true;
      _msg = '';
    });
    try {
      final rec = await audio.record(maxMs: 15000, silenceMs: 1400);
      if (!rec.heard) {
        _msg = 'No te oí. Habla un poco más cerca.';
      } else {
        final r = await api.upload('/speaking/mistakes/${widget.mistake['id']}/review', rec.wav) as Map;
        if (r['silent'] == true) {
          _msg = 'No se entendió. Prueba otra vez.';
        } else {
          _r = r;
          _tries++;
          widget.onXp(r['xp_gained'] as num?);
          await audio.say(widget.mistake['correct'] as String);
        }
      }
    } catch (e) {
      _msg = e.toString();
    }
    if (mounted) setState(() => _rec = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mistake, passed = _r?['passed'] == true;
    final done = _r != null && (passed || _tries >= 2);
    return StepPage(
      bottom: done
          ? FeedbackBar(ok: passed, title: passed ? '¡Bien dicho!' : 'Vuelve mañana', detail: m['correct'] as String, onNext: widget.onNext)
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MicButton(recording: _rec, onPressed: _rec ? null : _say),
                const SizedBox(height: 10),
                Text(_r == null ? 'Dilo bien en voz alta' : 'Otra vez', style: const TextStyle(color: W.muted)),
              ]),
            ),
      children: [
        stepKind('Tus errores · dilo bien'),
        const Text('Dijiste:', style: TextStyle(color: W.muted)),
        Text(m['said'] as String, style: const TextStyle(fontSize: 22, decoration: TextDecoration.lineThrough, color: W.bad)),
        if (m['why'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('💡 ${m['why']}', style: const TextStyle(color: W.muted))),
        if (_r != null && !passed) ...[
          const SizedBox(height: 12),
          Text('Entendí: “${_r!['heard']}”', style: const TextStyle(color: W.muted)),
          Text(m['correct'] as String, style: W.display(22, color: W.good, weight: FontWeight.w600)),
        ],
        if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_msg, style: const TextStyle(color: W.warn))),
      ],
    );
  }
}
