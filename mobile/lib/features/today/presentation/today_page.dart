import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../path/data/path_models.dart';
import '../../path/presentation/path_providers.dart';
import '../../session/data/session_plan.dart';
import '../data/today.dart';
import 'today_providers.dart';

/// Hoy: la meta de puntos y la sesión del día con un solo botón.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    return AsyncView<TodayData>(
      value: today,
      onRetry: () => ref.invalidate(todayProvider),
      data: (d) => RefreshIndicator(
        onRefresh: () => ref.refresh(todayProvider.future),
        child: _TodayBody(d: d, path: ref.watch(pathProvider).valueOrNull),
      ),
    );
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.d, this.path});
  final TodayData d;
  final PathData? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xp = d.xp;
    final name = ref.watch(authControllerProvider).valueOrNull?.firstName ?? '';
    final cards = d.reviews.length + d.newCards.length;
    final speak = const {'narrate': ('Hablar 1 min', 'narración del día'), 'picture': ('Hablar 45 s', 'describe una foto'), 'shadowing': ('Shadowing', 'repite como un nativo')}[d.speak] ??
        ('Hablar', 'un ejercicio');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(children: [
          Text('Word to Word', style: W.display(20)),
          const Spacer(),
          _Chip(icon: Icons.local_fire_department, color: const Color(0xFFE8790C), text: '${d.streak}'),
          const SizedBox(width: 8),
          _Chip(icon: Icons.bolt, color: W.accent, text: '${xp.total} XP'),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          SizedBox(width: 76, height: 76, child: CustomPaint(painter: _Ring(math.min(1, xp.xp / xp.goal)))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'Hola' : 'Hola, $name', style: const TextStyle(color: W.muted)),
              Text('${xp.xp} de ${xp.goal} XP', style: W.display(26)),
              Text(xp.goalMet ? '¡Meta de hoy cumplida!' : 'Te faltan ${xp.goal - xp.xp} XP para tu meta', style: const TextStyle(color: W.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: W.accent, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text(xp.sessions > 0 ? 'Otra ronda' : 'Sesión de hoy', style: W.display(24, color: Colors.white)),
              const Spacer(),
              const Text('unos 10 min', style: TextStyle(color: Colors.white70)),
            ]),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: [
                _Step(cards > 0 ? '$cards fichas' : 'Fichas', cards > 0 ? '${d.reviews.length} repasos · ${d.newCards.length} nuevas' : 'al día'),
                _Step(d.sounds.isNotEmpty ? 'Sonido /${d.sounds.first}/' : 'Pronunciación', 'tu más débil'),
                _Step(speak.$1, speak.$2),
                _Step(d.mistakes.isNotEmpty ? '${d.mistakes.length} ${d.mistakes.length == 1 ? 'error' : 'errores'}' : 'Errores',
                    d.mistakes.isNotEmpty ? 'dilos bien' : 'ninguno pendiente'),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: W.yellow, foregroundColor: W.yellowInk),
              onPressed: () => context.push(Routes.session, extra: SessionPlan.fromToday(d)),
              icon: const Icon(Icons.play_arrow),
              label: Text(xp.sessions > 0 ? 'Otra ronda' : 'Empezar'),
            ),
          ]),
        ),
        if (path != null && path!.units.isNotEmpty) ...[
          const SizedBox(height: 14),
          _PathCard(path: path!, onTap: () => context.go(Routes.path)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Mini('Hablaste hoy', '${d.minutes} min'.replaceAll('.', ','))),
          const SizedBox(width: 10),
          Expanded(child: _Mini('Esta semana', '${xp.weekTotal} XP')),
        ]),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: W.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: W.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class _Step extends StatelessWidget {
  const _Step(this.title, this.sub);
  final String title, sub;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: W.muted, fontSize: 13)),
            Text(value, style: W.display(22)),
          ]),
        ),
      );
}

class _PathCard extends StatelessWidget {
  const _PathCard({required this.path, required this.onTap});
  final PathData path;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cur = path.current;
    final steps = cur?.stepsDone ?? 4;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const CircleAvatar(backgroundColor: Color(0xFFE5F4EA), child: Icon(Icons.map, color: W.good)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Camino ${path.level} · ${cur == null ? 'completo' : 'Unidad ${cur.number}'}', style: const TextStyle(color: W.muted, fontSize: 13)),
                Text(cur == null ? '¡Todas las unidades hechas!' : cur.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: steps / 4, color: W.good, backgroundColor: W.line, minHeight: 6, borderRadius: BorderRadius.circular(9)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: W.muted),
          ]),
        ),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  _Ring(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(5), 0, math.pi * 2, false, p..color = W.line);
    canvas.drawArc(rect.deflate(5), -math.pi / 2, math.pi * 2 * value, false, p..color = W.good);
  }

  @override
  bool shouldRepaint(covariant _Ring old) => old.value != value;
}
