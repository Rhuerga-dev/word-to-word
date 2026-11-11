import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';
import '../../../../data/providers/api_client.dart';
import '../../../../data/services/audio_service.dart';
import '../../../../global_widgets/feedback_bar.dart';
import '../../../../global_widgets/step_page.dart';

// ---------- Palabra nueva ----------
class NewWordStepView extends StatefulWidget {
  const NewWordStepView({super.key, required this.card, required this.onXp, required this.onNext});
  final Map card;
  final void Function(num?) onXp;
  final VoidCallback onNext;
  @override
  State<NewWordStepView> createState() => _NewWordStepViewState();
}

class _NewWordStepViewState extends State<NewWordStepView> {
  bool? _ok;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Get.find<AppAudio>().say(widget.card['word'] as String);
  }

  Future<void> _learn() async {
    setState(() => _busy = true);
    try {
      final r = await Get.find<Api>().post('/words/${widget.card['id']}/learn');
      widget.onXp(r['xp_gained'] as num?);
      _ok = true;
    } catch (_) {
      _ok = false;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    return StepPage(
      bottom: _ok != null
          ? FeedbackBar(ok: _ok!, title: _ok! ? '¡Nueva palabra!' : 'No se guardó', detail: _ok! ? 'Mañana la repasas.' : null, onNext: widget.onNext)
          : bottomPad(FilledButton(onPressed: _busy ? null : _learn, child: const Text('La tengo'))),
      children: [
        stepKind('Palabra nueva'),
        Row(children: [
          Flexible(child: Text(c['word'] as String, style: W.display(46))),
          IconButton(tooltip: 'Escuchar', icon: const Icon(Icons.volume_up), onPressed: () => Get.find<AppAudio>().say(c['word'] as String)),
        ]),
        Text(c['translation'] as String? ?? '', style: const TextStyle(fontSize: 22, color: W.accent, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(plainExample(c['example'] as String?), style: const TextStyle(fontSize: 19)),
        Text(c['example_es'] as String? ?? '', style: const TextStyle(color: W.muted)),
        const SizedBox(height: 14),
        const Text('Dila en voz alta dos veces y úsala en una frase tuya.', style: TextStyle(color: W.muted)),
      ],
    );
  }
}
