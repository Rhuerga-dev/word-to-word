import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../session/data/session_plan.dart';
import '../data/words_repository.dart';

/// Tus palabras: cada día aprendes unas pocas nuevas y repasas las que tocan.
/// Las que recuerdas vuelven cada vez más tarde (1, 3, 7, 15, 30… días); las que olvidas, mañana.
class WordsPage extends ConsumerStatefulWidget {
  const WordsPage({super.key});

  @override
  ConsumerState<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends ConsumerState<WordsPage> {
  bool _saving = false;

  Future<void> _start(WordsDay d) async {
    final plan = SessionPlan([for (final c in d.reviews) ReviewStep(c), for (final c in d.newCards) NewStep(c)], title: tr('Tus palabras'));
    await context.push(Routes.session, extra: plan);
    if (mounted) ref.invalidate(wordsProvider);
  }

  Future<void> _daily(int n) async {
    setState(() => _saving = true);
    try {
      await ref.read(wordsRepositoryProvider).setDailyNew(n);
      if (mounted) ref.invalidate(wordsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: W.callBg,
      appBar: AppBar(title: Text(tr('Tus palabras')), backgroundColor: W.callBg),
      body: AsyncView<WordsDay>(
        value: ref.watch(wordsProvider),
        onRetry: () => ref.invalidate(wordsProvider),
        data: (d) {
          final total = d.cards.length;
          final maxF = d.forecast.fold<int>(1, (m, f) => f.$2 > m ? f.$2 : m);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(wordsProvider.future),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
              // El plan de hoy.
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: W.accent, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(tr('Plan de hoy'), style: const TextStyle(color: W.mist, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    total == 0 ? tr('¡Todo al día! Vuelve mañana.') : tr('Repasar {0} y aprender {1} nuevas', [d.reviews.length, d.newCards.length]),
                    style: W.display(24, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: d.dailyNew == 0 ? 0 : (d.newDone / d.dailyNew).clamp(0, 1).toDouble(),
                      minHeight: 8,
                      color: W.yellow,
                      backgroundColor: W.blueDeep,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(tr('Nuevas hoy: {0} de {1}', [d.newDone, d.dailyNew]), style: const TextStyle(color: W.mist, fontSize: 13)),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: W.accent, minimumSize: const Size.fromHeight(52)),
                    onPressed: total == 0 ? null : () => _start(d),
                    icon: const Icon(Icons.style),
                    label: Text(tr('Empezar fichas ({0})', [total])),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              // Cómo funciona el repaso.
              Text(tr('Cómo funciona'), style: W.display(19)),
              const SizedBox(height: 8),
              _how(Icons.wb_sunny_outlined, tr('Hoy aprendes tus palabras nuevas.')),
              _how(Icons.replay, tr('Mañana las repasas, junto con las nuevas de mañana.')),
              _how(Icons.calendar_month_outlined, tr('Las que recuerdas vuelven en 3 días, luego en una semana, 15 días, un mes…')),
              _how(Icons.lightbulb_outline, tr('Si una se te olvida, vuelve mañana. Crea una escena AID para fijarla.')),
              const SizedBox(height: 18),
              Text(tr('Repasos próximos 7 días'), style: W.display(19)),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final (day, n) in d.forecast)
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text('$n', style: const TextStyle(fontSize: 12, color: W.muted)),
                        const SizedBox(height: 2),
                        Container(
                          height: 4 + 64 * n / maxF,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(color: n == 0 ? W.line : W.accent, borderRadius: BorderRadius.circular(6)),
                        ),
                        const SizedBox(height: 4),
                        Text(_wd(day), style: const TextStyle(fontSize: 12, color: W.muted)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _stat('${d.learned}', tr('aprendidas'))),
                const SizedBox(width: 10),
                Expanded(child: _stat('${d.mastered}', tr('dominadas'))),
                const SizedBox(width: 10),
                Expanded(child: _stat('${d.byEar}', tr('de oído'))),
              ]),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Palabras nuevas por día'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(tr('Pocas cada día rinden más que muchas de golpe.'), style: const TextStyle(color: W.muted, fontSize: 13)),
                      ]),
                    ),
                    IconButton(onPressed: _saving || d.dailyNew <= 1 ? null : () => _daily(d.dailyNew - 1), icon: const Icon(Icons.remove_circle_outline)),
                    Text('${d.dailyNew}', style: W.display(20)),
                    IconButton(onPressed: _saving || d.dailyNew >= 50 ? null : () => _daily(d.dailyNew + 1), icon: const Icon(Icons.add_circle_outline)),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  static String _wd(DateTime d) {
    const es = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'], en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (Lang.english ? en : es)[d.weekday - 1];
  }

  Widget _how(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: W.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ]),
      );

  Widget _stat(String n, String label) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: W.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: W.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n, style: W.display(24, color: W.accent)),
          Text(label, style: const TextStyle(color: W.muted, fontSize: 13)),
        ]),
      );
}
