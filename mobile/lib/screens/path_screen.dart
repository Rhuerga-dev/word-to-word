import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../api.dart';
import '../theme.dart';
import 'session_screen.dart';

/// Camino: unidades del nivel, una abierta a la vez.
class PathScreen extends StatefulWidget {
  const PathScreen({super.key});
  @override
  State<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends State<PathScreen> {
  Map<String, dynamic>? _d;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Get.find<Api>().get('/path');
      if (mounted) setState(() => _d = Map<String, dynamic>.from(r as Map));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _continue(Map u) async {
    final steps = u['steps'] as Map;
    final api = Get.find<Api>();
    SessionPlan? plan;
    if (steps['words'] != true) {
      try {
        final r = await api.get('/path/units/${u['id']}/words');
        final cards = (r['cards'] as List).cast<Map>();
        if (cards.isNotEmpty) plan = SessionPlan([for (final c in cards) NewStep(c)], title: u['title'] as String, daily: false);
      } catch (e) {
        Get.snackbar('Camino', e.toString(), snackPosition: SnackPosition.BOTTOM);
        return;
      }
    }
    if (plan == null && steps['sound'] != true) {
      final k = soundKey(u['sound'] as String? ?? '');
      if (k != null) plan = SessionPlan([for (final w in soundWords[k]!) SoundStep(k, w)], title: u['title'] as String, daily: false);
    }
    if (plan == null) {
      Get.snackbar('Camino', 'El shadowing y la prueba de la unidad se hacen por ahora en la web (w2w.huergalabs.dev).', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await Get.to(() => SessionScreen(plan: plan!), fullscreenDialog: true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return Center(child: _error.isEmpty ? const CircularProgressIndicator() : Text(_error, style: const TextStyle(color: W.bad)));
    final units = (d['units'] as List).cast<Map>();
    final cur = units.indexWhere((u) => u['state'] == 'open');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        Text('TU CAMINO · ${d['level']} ${d['level_name'] ?? ''}'.toUpperCase(), style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.w700, color: W.muted, fontSize: 13)),
        Text(cur >= 0 ? 'Unidad ${cur + 1} de ${units.length}' : '${d['completed']} de ${units.length} unidades', style: W.display(26)),
        const SizedBox(height: 14),
        for (final u in units) Padding(padding: const EdgeInsets.only(bottom: 10), child: u['state'] == 'open' ? _Current(u: u, onGo: () => _continue(u)) : _Row(u: u)),
      ]),
    );
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
