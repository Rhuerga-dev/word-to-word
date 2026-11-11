import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';
import '../../../../data/providers/api_client.dart';
import '../../../../data/services/audio_service.dart';
import '../../../../global_widgets/feedback_bar.dart';
import '../../../../global_widgets/step_page.dart';

// ---------- Ficha de repaso ----------
class ReviewStepView extends StatefulWidget {
  const ReviewStepView({super.key, required this.card, required this.onGraded, required this.onNext});
  final Map card;
  final void Function(bool ok, num? xp) onGraded;
  final VoidCallback onNext;
  @override
  State<ReviewStepView> createState() => _ReviewStepViewState();
}

class _ReviewStepViewState extends State<ReviewStepView> {
  bool _shown = false, _busy = false;
  String? _grade;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.card['english_only'] != true) Get.find<AppAudio>().say(widget.card['word'] as String);
  }

  Future<void> _rate(String g) async {
    setState(() => _busy = true);
    try {
      final r = await Get.find<Api>().post('/words/${widget.card['id']}/review', {'grade': g});
      widget.onGraded(g != 'again', r['xp_gained'] as num?);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _grade = g);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card, en = c['english_only'] == true;
    final pv = (c['previews'] as Map?) ?? const {'again': 1, 'hard': 1, 'good': 3, 'easy': 7};
    final audio = Get.find<AppAudio>();
    final bottom = _grade != null
        ? FeedbackBar(
            ok: _grade != 'again' && _error == null,
            title: _error != null ? 'No se guardó' : (_grade == 'again' ? 'La repasarás pronto' : '¡Bien!'),
            detail: _error ?? '${c['word']} · ${c['translation']}',
            onNext: widget.onNext)
        : !_shown
            ? bottomPad(FilledButton(onPressed: () => setState(() => _shown = true), child: const Text('Ver la respuesta')))
            : bottomPad(Row(children: [
                for (final g in const [['again', 'Olvidé'], ['hard', 'Difícil'], ['good', 'Bien'], ['easy', 'Fácil']])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _rate(g[0]),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(g[1], style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(days(pv[g[0]] as num), style: const TextStyle(fontSize: 11, color: W.muted)),
                        ]),
                      ),
                    ),
                  ),
              ]));
    return StepPage(bottom: bottom, children: [
      stepKind(en && !_shown ? 'Solo inglés · ¿qué palabra falta?' : 'Repaso · ¿qué significa?'),
      if (en && !_shown) ...[
        if (c['definition'] != null) Text(c['definition'] as String, style: W.display(22, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(plainExample(c['example'] as String?, cloze: true), style: const TextStyle(fontSize: 20)),
      ] else ...[
        Row(children: [
          Flexible(child: Text(c['word'] as String, style: W.display(46))),
          IconButton(tooltip: 'Escuchar', icon: const Icon(Icons.volume_up), onPressed: () => audio.say(c['word'] as String)),
        ]),
        if (_shown) ...[
          const SizedBox(height: 8),
          Text(en && c['definition'] != null ? c['definition'] as String : c['translation'] as String,
              style: const TextStyle(fontSize: 22, color: W.accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(plainExample(c['example'] as String?), style: const TextStyle(fontSize: 19)),
          if (en) Text(c['translation'] as String, style: const TextStyle(color: W.muted)),
        ],
      ],
      const SizedBox(height: 12),
      if (!_shown) const Text('Dilo en voz alta antes de ver la respuesta.', style: TextStyle(color: W.muted)),
    ]);
  }
}
