import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/path_controller.dart';

/// Camino: unidades del nivel, una abierta a la vez.
class PathView extends GetView<PathController> {
  const PathView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
    final d = controller.data.value;
    if (d == null) return Center(child: controller.error.value.isEmpty ? const CircularProgressIndicator() : Text(controller.error.value, style: const TextStyle(color: W.bad)));
    final units = (d['units'] as List).cast<Map>();
    final cur = units.indexWhere((u) => u['state'] == 'open');
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        Text('TU CAMINO · ${d['level']} ${d['level_name'] ?? ''}'.toUpperCase(), style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.w700, color: W.muted, fontSize: 13)),
        Text(cur >= 0 ? 'Unidad ${cur + 1} de ${units.length}' : '${d['completed']} de ${units.length} unidades', style: W.display(26)),
        const SizedBox(height: 14),
        for (final u in units) Padding(padding: const EdgeInsets.only(bottom: 10), child: u['state'] == 'open' ? _Current(u: u, onGo: () => controller.continueUnit(u)) : _Row(u: u)),
      ]),
    );
    });
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.u});
  final Map u;
  @override
  Widget build(BuildContext context) {
    final done = u['state'] == 'done';
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
            Text('${u['number']} · ${u['title']}', style: TextStyle(fontWeight: FontWeight.w700, color: done ? W.ink : W.muted)),
            Text(done ? 'Completada' : 'Se abre al pasar la prueba anterior', style: const TextStyle(fontSize: 13, color: W.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _Current extends StatelessWidget {
  const _Current({required this.u, required this.onGo});
  final Map u;
  final VoidCallback onGo;
  @override
  Widget build(BuildContext context) {
    final s = u['steps'] as Map, w = u['words'] as Map;
    final n = ['words', 'sound', 'shadow', 'test'].where((k) => s[k] == true).length;
    final next = ['words', 'sound', 'shadow', 'test'].firstWhere((k) => s[k] != true, orElse: () => 'test');
    final test = u['test'] as Map;
    final items = <(String, String)>[
      ('words', 'Palabras: ${(w['preview'] as List).join(', ')} (${w['learned']} de ${w['need']})'),
      ('sound', 'Sonido /${u['sound']}/'),
      ('shadow', 'Shadowing de la unidad'),
      ('test', 'Prueba: ${u['scenario_title']}${test['score'] != null ? ' · mejor nota ${test['score']}/10' : ''}'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: W.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: W.accent, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text('${u['number']} · ${u['title']}', style: W.display(21))),
          Text('$n de 4', style: const TextStyle(color: W.accent, fontWeight: FontWeight.w700)),
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
                  color: s[k] == true ? const Color(0xFFE5F4EA) : (k == next ? W.accent : W.bg),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(s[k] == true ? Icons.check : (k == next ? Icons.play_arrow : Icons.lock_outline), size: 17, color: s[k] == true ? W.good : (k == next ? Colors.white : W.muted)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontWeight: k == next ? FontWeight.w700 : FontWeight.w400, color: s[k] == true || k == next ? W.ink : W.muted))),
            ]),
          ),
        if (test['feedback'] != null && s['test'] != true) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${test['feedback']}', style: const TextStyle(color: W.muted, fontSize: 14))),
        const SizedBox(height: 4),
        FilledButton(onPressed: onGo, child: const Text('Continuar la unidad')),
      ]),
    );
  }
}
