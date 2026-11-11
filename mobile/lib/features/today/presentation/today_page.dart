import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/services/hands_free.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../path/data/path_models.dart';
import '../../path/presentation/path_providers.dart';
import '../../session/data/session_plan.dart';
import '../data/today.dart';
import 'today_providers.dart';
import '../../../core/l10n/tr.dart';

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
    final handsFree = ref.watch(handsFreeProvider.select((h) => h.on));
    final cards = d.reviews.length + d.newCards.length;
    final hour = DateTime.now().hour;
    final hello = hour < 12 ? tr('Buenos días') : (hour < 20 ? tr('Buenas tardes') : tr('Buenas noches'));
    final speak = {'narrate': tr('Contar tu día durante un minuto'), 'picture': tr('Describir una foto'), 'shadowing': tr('Repetir como un nativo')}[d.speak] ?? tr('Hablar un minuto');
    final agenda = <(String, String)>[
      if (!d.offline && d.ear.isNotEmpty) (trn(d.ear.length, 'Oído: reconoce {0} palabra al oírla', 'Oído: reconoce {0} palabras al oírlas'), '1 min'),
      if (cards > 0) (trn(cards, 'Calentamiento con {0} ficha', 'Calentamiento con {0} fichas'), '${(cards * 15 / 60).ceil()} min'),
      if (!d.offline) (tr('El sonido /{0}/', [d.sounds.isNotEmpty ? d.sounds.first : defaultSound()]), '2 min'),
      if (!d.offline) (speak, '2 min'),
      if (!d.offline && d.mistakes.isNotEmpty) (trn(d.mistakes.length, 'Dices bien {0} error de ayer', 'Dices bien {0} errores de ayer'), '1 min'),
    ];
    final plan = d.offline ? SessionPlan.offline(d) : SessionPlan.fromToday(d);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      children: [
        Row(children: [
          Expanded(child: Text(name.isEmpty ? hello : '$hello, $name', style: const TextStyle(fontSize: 17, color: W.muted))),
          const Icon(Icons.local_fire_department, color: Color(0xFFE8790C), size: 20),
          const SizedBox(width: 4),
          Text(trn(d.streak, '{0} día', '{0} días'), style: const TextStyle(fontWeight: FontWeight.w700, color: W.streak)),
        ]),
        const SizedBox(height: 22),
        Center(child: _MicRings(progress: math.min(1, xp.xp / xp.goal))),
        const SizedBox(height: 18),
        Text(xp.sessions > 0 ? tr('Otra ronda') : tr('Tu sesión de hoy'), textAlign: TextAlign.center, style: W.display(30)),
        const SizedBox(height: 6),
        Text(
          xp.goalMet ? tr('¡Meta de hoy cumplida! {0} XP. Otra ronda suma más.', [xp.xp]) : tr('Unos 10 minutos con tu coach. Llevas {0} de {1} XP hoy.', [xp.xp, xp.goal]),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: W.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: W.yellow, foregroundColor: W.yellowInk, shape: const StadiumBorder(), minimumSize: const Size.fromHeight(58)),
          onPressed: plan.steps.isEmpty ? null : () => context.push(Routes.session, extra: plan),
          icon: Icon(handsFree ? Icons.headphones : Icons.play_arrow),
          label: Text(xp.sessions > 0 ? tr('Empezar otra ronda') : tr('Empezar la sesión')),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(tr('Manos libres'), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(tr('La app habla, te escucha y sigue sola. Ideal con AirPods.')),
          value: handsFree,
          onChanged: (v) => ref.read(handsFreeProvider.notifier).setOn(v),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('En la sesión'), style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (agenda.isEmpty) Text(tr('Todo al día. Puedes practicar lo que quieras.'), style: TextStyle(color: W.muted)),
            for (final (what, time) in agenda)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [Expanded(child: Text(what, style: const TextStyle(fontSize: 15))), Text(time, style: const TextStyle(color: W.muted))]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFF6C7), child: Icon(Icons.style, color: Color(0xFFB4560A))),
            title: Text(tr('Tus palabras'), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(tr('Nuevas de hoy y repasos que tocan, con tu escena AID')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.words),
          ),
        ),
        if (path != null && path!.units.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PathCard(path: path!, onTap: () => context.go(Routes.path)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Mini(tr('Hablaste hoy'), '${d.minutes} min'.replaceAll('.', ','))),
          const SizedBox(width: 10),
          Expanded(child: _Mini(tr('Esta semana'), '${xp.weekTotal} XP')),
        ]),
      ],
    );
  }
}

/// El círculo del coach: anillos azules con el micrófono; el borde verde es la meta de hoy.
class _MicRings extends StatelessWidget {
  const _MicRings({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(alignment: Alignment.center, children: [
        Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: W.ringLight)),
        CustomPaint(size: const Size(220, 220), painter: _Ring(progress)),
        Container(width: 164, height: 164, decoration: const BoxDecoration(shape: BoxShape.circle, color: W.ringMid)),
        Container(
          width: 108,
          height: 108,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: W.accent),
          child: const Icon(Icons.mic, color: Colors.white, size: 46),
        ),
      ]),
    );
  }
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
                Text(cur == null ? tr('Camino {0} · completo', [path.level]) : tr('Camino {0} · Unidad {1}', [path.level, cur.number]), style: const TextStyle(color: W.muted, fontSize: 13)),
                Text(cur == null ? tr('¡Todas las unidades hechas!') : cur.title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(5), 0, math.pi * 2, false, p..color = W.line);
    canvas.drawArc(rect.deflate(5), -math.pi / 2, math.pi * 2 * value, false, p..color = W.good);
  }

  @override
  bool shouldRepaint(covariant _Ring old) => old.value != value;
}
