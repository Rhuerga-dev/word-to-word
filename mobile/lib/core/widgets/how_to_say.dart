import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/tr.dart';
import '../services/audio_service.dart';
import '../services/hands_free.dart';
import '../theme/app_theme.dart';
import '../utils/pron_tips.dart';
import 'w2w_loader.dart';

/// Manos libres: dice la primera técnica (en español mientras la app está en español: [spanish]).
Future<void> sayTip(HandsFreeController hf, List<WordTips> tips, {required bool spanish}) async {
  if (tips.isEmpty) return;
  final w = tips.first;
  final t = w.tips.first;
  if (spanish) {
    await hf.say('Para "${w.word}": ${t.how}', lang: 'es');
  } else {
    await hf.say('Tip for ${w.word}: ${tr(t.how)}');
  }
}

/// "Cómo decirla": las palabras que no se entendieron y la técnica para sus sonidos.
class HowToSay extends ConsumerWidget {
  const HowToSay({super.key, required this.tips, required this.loading, required this.target});
  final List<WordTips> tips;
  final bool loading;
  final String target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(color: W.warn.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: W.warn.withValues(alpha: .3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.record_voice_over, size: 20, color: W.warn),
          const SizedBox(width: 8),
          Text(tr('Cómo decirla'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (loading) ...[
            const SizedBox(width: 10),
            const W2WLoader.small(),
          ],
        ]),
        for (final w in tips) ...[
          const SizedBox(height: 10),
          Text('“${w.word}”', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: W.bad)),
          for (final t in w.tips)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(t.name), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(tr(t.how), style: const TextStyle(height: 1.35)),
                if (t.pair.isNotEmpty) Text('${tr('Practica:')} ${t.pair}', style: const TextStyle(color: W.muted)),
              ]),
            ),
        ],
        if (!loading) ...[
          const SizedBox(height: 10),
          Text(tr(slowToNormal.name), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(tr(slowToNormal.how), style: const TextStyle(height: 1.35)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => ref.read(audioProvider).say(target, slow: true),
              icon: const Icon(Icons.slow_motion_video),
              label: Text(tr('Oírla despacio')),
            ),
          ),
        ],
      ]),
    );
  }
}
