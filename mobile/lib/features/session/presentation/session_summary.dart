import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/step_page.dart';
import '../data/session_repository.dart';

/// Fin de la sesión: puntos, aciertos, tiempo, racha y logros nuevos.
class SessionSummary extends StatelessWidget {
  const SessionSummary({super.key, required this.result, required this.xp, required this.right, required this.graded, required this.minutes, this.title});
  final SessionResult? result;
  final int xp, right, graded, minutes;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const Center(child: CircularProgressIndicator());
    final x = r.xp;
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
              child: Text(x.goalMet ? 'Cumpliste tu meta de hoy' : 'Llevas ${x.xp} de ${x.goal} XP hoy', textAlign: TextAlign.center, style: const TextStyle(color: W.muted)),
            ),
          const SizedBox(height: 20),
          Row(children: [
            _tile('PUNTOS', '+${xp + r.xpGained}', W.accent),
            const SizedBox(width: 8),
            _tile('FICHAS BIEN', graded == 0 ? '—' : '${(right * 100 / graded).round()}%', W.good),
            const SizedBox(width: 8),
            _tile('TIEMPO', '${minutes < 1 ? 1 : minutes} min', const Color(0xFFC0640C)),
          ]),
          if (r.streak != null) Padding(padding: const EdgeInsets.only(top: 18), child: Text('🔥 ${r.streak} días seguidos', textAlign: TextAlign.center, style: W.display(20))),
          if (r.learned > 0) Text('✓ ${r.learned} palabras nuevas'),
          if (r.mistakesOk > 0) Text('✓ ${r.mistakesOk} errores dichos bien'),
          for (final a in r.achievements)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text('🏅 ¡Nuevo logro! ${a.title} · ${a.desc}', style: const TextStyle(color: W.good, fontWeight: FontWeight.w700))),
        ]),
      ),
      bottomPad(FilledButton(onPressed: () => context.pop(), child: const Text('Continuar'))),
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
