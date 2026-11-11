import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/today_controller.dart';

/// Hoy: la meta de puntos y la sesión del día con un solo botón.
class TodayView extends GetView<TodayController> {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final d = controller.data.value, p = controller.path.value;
      if (d == null) {
        return Center(child: controller.error.value.isEmpty ? const CircularProgressIndicator() : Text(controller.error.value, style: const TextStyle(color: W.bad)));
      }
    final xp = d['xp'] as Map, plan = d['plan'] as Map;
    final reviews = (plan['reviews'] as List).length, fresh = (plan['new'] as List).length, mistakes = (plan['mistakes'] as List).length;
    final sounds = plan['sounds'] as List;
    final goal = (xp['goal'] as num).toInt(), got = (xp['xp'] as num).toInt();
    final name = Get.find<AuthService>().firstName;
    final speak = const {'narrate': ['Hablar 1 min', 'narración del día'], 'picture': ['Hablar 45 s', 'describe una foto'], 'shadowing': ['Shadowing', 'repite como un nativo']}[plan['speak']] ??
        ['Hablar', 'un ejercicio'];

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(children: [
            Text('Word to Word', style: W.display(20)),
            const Spacer(),
            _Chip(icon: Icons.local_fire_department, color: const Color(0xFFE8790C), text: '${d['streak']}'),
            const SizedBox(width: 8),
            _Chip(icon: Icons.bolt, color: W.accent, text: '${xp['total']} XP'),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            SizedBox(width: 76, height: 76, child: CustomPaint(painter: _Ring(math.min(1, got / goal)))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Hola' : 'Hola, $name', style: const TextStyle(color: W.muted)),
                Text('$got de $goal XP', style: W.display(26)),
                Text(got >= goal ? '¡Meta de hoy cumplida!' : 'Te faltan ${goal - got} XP para tu meta', style: const TextStyle(color: W.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: W.accent, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text((xp['sessions'] as num) > 0 ? 'Otra ronda' : 'Sesión de hoy', style: W.display(24, color: Colors.white)),
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
                  _Step(reviews + fresh > 0 ? '${reviews + fresh} fichas' : 'Fichas', reviews + fresh > 0 ? '$reviews repasos · $fresh nuevas' : 'al día'),
                  _Step(sounds.isNotEmpty ? 'Sonido /${sounds.first['phoneme']}/' : 'Pronunciación', 'tu más débil'),
                  _Step(speak[0], speak[1]),
                  _Step(mistakes > 0 ? '$mistakes ${mistakes == 1 ? 'error' : 'errores'}' : 'Errores', mistakes > 0 ? 'dilos bien' : 'ninguno pendiente'),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: W.yellow, foregroundColor: W.yellowInk),
                onPressed: controller.start,
                icon: const Icon(Icons.play_arrow),
                label: Text((xp['sessions'] as num) > 0 ? 'Otra ronda' : 'Empezar'),
              ),
            ]),
          ),
          if (p != null && (p['units'] as List).isNotEmpty) ...[
            const SizedBox(height: 14),
            _PathCard(path: p, onTap: () => Get.find<HomeController>().go(1)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _Mini('Hablaste hoy', '${d['minutes']} min'.replaceAll('.', ','))),
            const SizedBox(width: 10),
            Expanded(child: _Mini('Esta semana', '${(xp['week'] as List).fold<num>(0, (a, w) => a + (w['xp'] as num))} XP')),
          ]),
        ],
      ),
    );
    });
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
  final Map<String, dynamic> path;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final units = path['units'] as List;
    final cur = units.cast<Map>().where((u) => u['id'] == path['current']).firstOrNull;
    final steps = cur == null ? 4 : ['words', 'sound', 'shadow', 'test'].where((k) => cur['steps'][k] == true).length;
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
                Text('Camino ${path['level']} · ${cur == null ? 'completo' : 'Unidad ${cur['number']}'}', style: const TextStyle(color: W.muted, fontSize: 13)),
                Text(cur == null ? '¡Todas las unidades hechas!' : '${cur['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
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
