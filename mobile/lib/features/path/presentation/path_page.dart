import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../session/data/session_plan.dart';
import '../data/path_models.dart';
import '../data/path_repository.dart';
import 'path_providers.dart';
import '../../../core/l10n/tr.dart';

/// Camino: unidades del nivel, una abierta a la vez.
class PathPage extends ConsumerWidget {
  const PathPage({super.key});

  /// Arma el siguiente paso de la unidad que se puede hacer en la app.
  Future<void> _continue(BuildContext context, WidgetRef ref, PathUnit u) async {
    final messenger = ScaffoldMessenger.of(context);
    SessionPlan? plan;
    if (u.steps['words'] != true) {
      try {
        final cards = await ref.read(pathRepositoryProvider).unitWords(u.id);
        if (cards.isNotEmpty) plan = SessionPlan([for (final c in cards) NewStep(c)], title: u.title);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
        return;
      }
    }
    if (plan == null && u.steps['sound'] != true) {
      final k = soundKey(u.sound);
      if (k != null) plan = SessionPlan.sound(k, title: u.title);
    }
    if (plan == null) {
      messenger.showSnackBar(SnackBar(content: Text(tr('El shadowing y la prueba de la unidad se hacen por ahora en la web (w2w.huergalabs.dev).'))));
      return;
    }
    if (context.mounted) context.push(Routes.session, extra: plan);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<PathData>(
      value: ref.watch(pathProvider),
      onRetry: () => ref.invalidate(pathProvider),
      data: (d) {
        final cur = d.units.indexWhere((u) => u.state == UnitState.open);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(pathProvider.future),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
            Text(tr('TU CAMINO · {0} {1}', [d.level, d.levelName]).toUpperCase(), style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.w700, color: W.muted, fontSize: 13)),
            Text(cur >= 0 ? tr('Unidad {0} de {1}', [cur + 1, d.units.length]) : tr('{0} de {1} unidades', [d.completed, d.units.length]), style: W.display(26)),
            const SizedBox(height: 14),
            for (final u in d.units)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: u.state == UnitState.open ? _Current(u: u, onGo: () => _continue(context, ref, u)) : _Row(u: u),
              ),
          ]),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.u});
  final PathUnit u;
  @override
  Widget build(BuildContext context) {
    final done = u.state == UnitState.done;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: done ? W.card : const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: done ? W.line : const Color(0xFFB9C4D2)),
      ),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: done ? W.good : const Color(0xFFE3E8EF), child: Icon(done ? Icons.check : Icons.lock_outline, size: 18, color: done ? Colors.white : W.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u.number} · ${u.title}', style: TextStyle(fontWeight: FontWeight.w700, color: done ? W.ink : W.muted)),
            Text(done ? 'Completada' : tr('Se abre al pasar la prueba anterior'), style: const TextStyle(fontSize: 13, color: W.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _Current extends StatelessWidget {
  const _Current({required this.u, required this.onGo});
  final PathUnit u;
  final VoidCallback onGo;
  @override
  Widget build(BuildContext context) {
    final next = u.nextStep;
    final items = <(String, String)>[
      ('words', tr('Palabras: {0} ({1} de {2})', [u.preview.join(', '), u.wordsLearned, u.wordsNeed])),
      ('sound', tr('Sonido /{0}/', [u.sound])),
      ('shadow', tr('Shadowing de la unidad')),
      ('test', u.testScore != null ? tr('Prueba: {0} · mejor nota {1}/10', [u.scenarioTitle, u.testScore]) : tr('Prueba: {0}', [u.scenarioTitle])),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: W.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: W.accent, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text('${u.number} · ${u.title}', style: W.display(21))),
          Text(tr('{0} de 4', [u.stepsDone]), style: const TextStyle(color: W.accent, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        for (final (k, label) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: u.steps[k] == true ? const Color(0xFFE5F4EA) : (k == next ? W.accent : W.bg),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(u.steps[k] == true ? Icons.check : (k == next ? Icons.play_arrow : Icons.lock_outline),
                    size: 17, color: u.steps[k] == true ? W.good : (k == next ? Colors.white : W.muted)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(fontWeight: k == next ? FontWeight.w700 : FontWeight.w400, color: u.steps[k] == true || k == next ? W.ink : W.muted)),
              ),
            ]),
          ),
        if (u.testFeedback != null && u.steps['test'] != true)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(u.testFeedback!, style: const TextStyle(color: W.muted, fontSize: 14))),
        const SizedBox(height: 4),
        FilledButton(onPressed: onGo, child: Text(tr('Continuar la unidad'))),
      ]),
    );
  }
}
