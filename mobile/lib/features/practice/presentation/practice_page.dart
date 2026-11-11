import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../session/data/session_plan.dart';
import '../data/practice_repository.dart';
import 'practice_providers.dart';

/// Practicar: elige tú qué hacer. Todo suma puntos.
class PracticePage extends ConsumerWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void run(List<SessionStep> steps, String title) {
      if (steps.isNotEmpty) context.push(Routes.session, extra: SessionPlan(steps, title: title));
    }

    final ph = defaultSound();
    return AsyncView<PracticeData>(
      value: ref.watch(practiceProvider),
      onRetry: () => ref.invalidate(practiceProvider),
      data: (d) => RefreshIndicator(
        onRefresh: () => ref.refresh(practiceProvider.future),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          Text('Practicar', style: W.display(26)),
          const Text('Elige tú qué hacer. Todo suma puntos a tu meta.', style: TextStyle(color: W.muted)),
          const SizedBox(height: 14),
          if (d.mistakes.isNotEmpty)
            Card(
              color: const Color(0xFFFFF7EC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFF3D7B2))),
              child: ListTile(
                leading: const Icon(Icons.replay, color: Color(0xFFA85A00)),
                title: Text('${d.mistakes.length} ${d.mistakes.length == 1 ? 'error' : 'errores'} para repasar', style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Text('Repasar', style: TextStyle(color: W.accent, fontWeight: FontWeight.w700)),
                onTap: () => run([for (final m in d.mistakes) MistakeStep(m)], 'Errores'),
              ),
            ),
          const SizedBox(height: 8),
          _label('Hablar'),
          _tile(Icons.timer_outlined, 'Narración', '1 minuto sin parar', () => run(const [NarrateStep()], 'Narración')),
          _label('Palabras y sonidos'),
          _tile(Icons.style_outlined, 'Fichas', d.cards.isEmpty ? 'nada pendiente hoy' : '${d.cards.length} para hoy',
              d.cards.isEmpty ? null : () => run([for (final c in d.cards) c.isNew ? NewStep(c) : ReviewStep(c)], 'Fichas')),
          _tile(Icons.track_changes, 'Pronunciación', '/$ph/ · ${soundWords[ph]!.join(', ')}', () => run(SessionPlan.sound(ph).steps, 'Sonido')),
          const SizedBox(height: 14),
          const Text('Conversación, Describe la imagen, Shadowing y el chat escrito siguen en la web por ahora.', style: TextStyle(color: W.muted, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(t.toUpperCase(), style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.w700, color: W.muted, fontSize: 13)),
      );

  Widget _tile(IconData icon, String title, String sub, VoidCallback? onTap) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          minVerticalPadding: 12,
          leading: Icon(icon, color: onTap == null ? W.muted : W.accent),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
          enabled: onTap != null,
          onTap: onTap,
        ),
      );
}
