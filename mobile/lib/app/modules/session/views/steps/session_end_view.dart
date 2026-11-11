import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../global_widgets/step_page.dart';

// ---------- Fin ----------
class SessionEndView extends StatelessWidget {
  const SessionEndView({super.key, required this.data, required this.xp, required this.right, required this.graded, required this.minutes, this.title});
  final Map<String, dynamic>? data;
  final int xp, right, graded, minutes;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final x = d['xp'] as Map?;
    final ach = (d['achievements'] as List?) ?? const [];
    final today = (d['today'] as Map?) ?? const {};
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(color: W.yellow, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 56, color: W.yellowInk),
            ),
          ),
          const SizedBox(height: 18),
          Text(title == null ? '¡Sesión completa!' : '¡Listo!', textAlign: TextAlign.center, style: W.display(32)),
          if (x != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text((x['xp'] as num) >= (x['goal'] as num) ? 'Cumpliste tu meta de hoy' : 'Llevas ${x['xp']} de ${x['goal']} XP hoy',
                  textAlign: TextAlign.center, style: const TextStyle(color: W.muted)),
            ),
          const SizedBox(height: 20),
          Row(children: [
            _tile('PUNTOS', '+${xp + ((d['xp_gained'] as num?) ?? 0).toInt()}', W.accent),
            const SizedBox(width: 8),
            _tile('FICHAS BIEN', graded == 0 ? '—' : '${(right * 100 / graded).round()}%', W.good),
            const SizedBox(width: 8),
            _tile('TIEMPO', '${minutes < 1 ? 1 : minutes} min', const Color(0xFFC0640C)),
          ]),
          if (d['streak'] != null) Padding(padding: const EdgeInsets.only(top: 18), child: Text('🔥 ${d['streak']} días seguidos', textAlign: TextAlign.center, style: W.display(20))),
          if ((today['learned'] ?? 0) > 0) Text('✓ ${today['learned']} palabras nuevas'),
          if ((today['mistakes_ok'] ?? 0) > 0) Text('✓ ${today['mistakes_ok']} errores dichos bien'),
          for (final a in ach) Padding(padding: const EdgeInsets.only(top: 10), child: Text('🏅 ¡Nuevo logro! ${a['title']} · ${a['desc']}', style: const TextStyle(color: W.good, fontWeight: FontWeight.w700))),
        ]),
      ),
      bottomPad(FilledButton(onPressed: () => Get.back(result: true), child: const Text('Continuar'))),
    ]);
  }

  Widget _tile(String label, String value, Color c) => Expanded(
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: c, width: 2), borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Container(width: double.infinity, color: c, padding: const EdgeInsets.symmetric(vertical: 5), child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(value, style: W.display(22))),
          ]),
        ),
      );
}
