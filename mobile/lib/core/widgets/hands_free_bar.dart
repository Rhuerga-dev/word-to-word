import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio_service.dart';
import '../services/hands_free.dart';
import '../theme/app_theme.dart';
import '../../core/l10n/tr.dart';

/// La barra del modo manos libres: qué está pasando, las órdenes de voz y "Pausar".
class HandsFreeBar extends ConsumerWidget {
  const HandsFreeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(handsFreeProvider);
    final (label, icon) = switch (s.phase) {
      HfPhase.speaking => (tr('Tu coach habla'), Icons.volume_up),
      HfPhase.listening => ('Te escucho', Icons.mic),
      HfPhase.thinking => ('Pensando…', Icons.more_horiz),
      HfPhase.idle => ('Manos libres', Icons.headphones),
    };
    final listening = s.phase == HfPhase.listening;
    final phones = ref.watch(headphonesProvider).valueOrNull;
    return Container(
      decoration: const BoxDecoration(color: W.navy, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: listening ? W.yellow : W.blueDeep,
                boxShadow: [BoxShadow(color: (listening ? W.yellow : W.mist).withValues(alpha: .25), spreadRadius: listening ? 8 : 4)],
              ),
              child: Icon(icon, color: listening ? W.navy : Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: W.display(20, color: Colors.white)),
                if (s.heard.isNotEmpty)
                  Text('“${s.heard}”', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: W.mist))
                else if (s.prompt.isNotEmpty)
                  Text(s.prompt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: W.mist)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(phones != null ? Icons.headphones : Icons.volume_up, size: 18, color: W.mist),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                phones != null ? '$phones · ${tr('hablas al micrófono del teléfono')}' : tr('Sin auriculares: la voz sale por el altavoz'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: W.mist, fontSize: 13),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in const ['repeat', 'slower', 'help', 'next', 'stop'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Text(c, style: const TextStyle(color: W.navy, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF5B7FE6), width: 2), shape: const StadiumBorder(), minimumSize: const Size.fromHeight(48)),
            onPressed: () => ref.read(handsFreeProvider.notifier).pause(),
            child: Text(tr('Pausar manos libres'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
