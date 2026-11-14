import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../data/progress_models.dart';
import '../data/progress_repository.dart';
import 'progress_providers.dart';
import '../../../core/l10n/tr.dart';

/// Progreso: números claros, liga de la semana, logros, sonidos y errores. Los ajustes van en la pestaña Ajustes.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<ProgressBundle>(
      value: ref.watch(progressProvider),
      onRetry: () => ref.invalidate(progressProvider),
      data: (b) {
        final p = b.progress, l = b.league, a = b.achievements;
        return RefreshIndicator(
          onRefresh: () => ref.refresh(progressProvider.future),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
            Text(tr('Progreso'), style: W.display(26)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _stat('${p.wordsLearned}', tr('palabras aprendidas')),
                _stat('${p.speakingMinutes}', tr('minutos hablando')),
                _stat('${p.streak}', tr('días seguidos')),
                _stat('${p.mistakesMastered}', tr('errores superados')),
              ],
            ),
            for (final t in p.todo) Padding(padding: const EdgeInsets.only(top: 8), child: Text(t)),
            _h(tr('Liga de la semana')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(l.myRank == null ? tr('Aún sin puntos esta semana') : tr('Vas en el puesto {0} de {1} · quedan {2} días', [l.myRank, l.players, l.daysLeft]),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final r in l.top)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        SizedBox(width: 28, child: Text('${r.rank}', style: const TextStyle(color: W.muted))),
                        Expanded(child: Text('${r.name}${r.me ? tr(' (tú)') : ''}', style: TextStyle(fontWeight: r.me ? FontWeight.w700 : FontWeight.w400))),
                        Text('${r.xp} XP'),
                      ]),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('Aparecer en la liga')),
                    value: l.visible,
                    onChanged: (v) async {
                      await ref.read(progressRepositoryProvider).setLeagueVisible(v);
                      ref.invalidate(progressProvider);
                    },
                  ),
                ]),
              ),
            ),
            _h(tr('Logros · {0} de {1}', [a.unlocked, a.total])),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in a.list)
                Tooltip(
                  message: x.desc,
                  child: Chip(
                    avatar: Icon(x.unlocked ? Icons.emoji_events : Icons.lock_outline, size: 18, color: x.unlocked ? const Color(0xFFC0640C) : W.muted),
                    label: Text(x.title),
                    backgroundColor: x.unlocked ? const Color(0xFFFFF6C7) : W.card,
                  ),
                ),
            ]),
            if (p.sounds.isNotEmpty) ...[
              _h('Sonidos'),
              for (final s in p.sounds)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('/${s.phoneme}/'),
                  subtitle: Text(s.label),
                  trailing: Text('${s.errors} fallos', style: const TextStyle(color: W.muted)),
                ),
            ],
            if (p.mistakesByCategory.isNotEmpty) ...[
              _h(tr('Tus errores por tipo')),
              for (final (label, count) in p.mistakesByCategory) Text('$label: $count'),
            ],
          ]),
        );
      },
    );
  }

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: Text(tr(t), style: W.display(19)));

  Widget _stat(String n, String label) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: W.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: W.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(n, style: W.display(26, color: W.accent)),
          Text(label, style: const TextStyle(color: W.muted, fontSize: 13)),
        ]),
      );
}
