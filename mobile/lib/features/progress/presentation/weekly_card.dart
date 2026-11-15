import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../data/progress_models.dart';

/// «Tu semana hablando»: estos 7 días contra los 7 anteriores (GET /speaking/weekly).
/// Cada número lleva su cambio: verde si mejoró, rojo si empeoró (en la reacción, menos es mejor).
class WeeklyCard extends StatelessWidget {
  const WeeklyCard(this.w, {super.key});
  final WeeklyFluency w;

  @override
  Widget build(BuildContext context) {
    final now = w.now, before = w.before;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (now.empty)
            Text(tr('Aún no hablaste esta semana'), style: const TextStyle(fontWeight: FontWeight.w700))
          else ...[
            Text(tr('Estos 7 días contra los 7 anteriores'), style: const TextStyle(color: W.muted, fontSize: 13)),
            const SizedBox(height: 6),
            _row(tr('Minutos hablando'), num1(now.minutes), change(now.minutes, before.minutes)),
            _row(tr('Palabras por minuto'), now.wpm == null ? '—' : '${now.wpm}', change(now.wpm, before.wpm)),
            _row(tr('Reacción'), now.reaction == null ? '—' : tr('{0} s', [num1(now.reaction!)]), change(now.reaction, before.reaction, lowerIsBetter: true)),
          ],
          _row(tr('Errores superados'), '${now.mistakesMastered}', change(now.mistakesMastered, before.mistakesMastered)),
          for (final (said, correct) in w.conquered)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(tr('Ya no dices «{0}» → «{1}»', [said, correct]), style: const TextStyle(color: W.good, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, Change? c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(
            width: 64,
            child: c == null ? null : Text(c.text, textAlign: TextAlign.end, style: TextStyle(color: c.color, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

/// El cambio de un número contra la semana pasada.
class Change {
  const Change(this.text, this.better);
  final String text;

  /// true = mejoró · false = empeoró · null = igual.
  final bool? better;

  Color get color => better == null ? W.muted : (better! ? W.good : W.bad);
}

/// null si falta alguno de los dos números (no se puede comparar).
Change? change(num? now, num? before, {bool lowerIsBetter = false}) {
  if (now == null || before == null) return null;
  final d = now - before;
  if (d.abs() < 0.05) return const Change('=', null);
  final up = d > 0;
  return Change('${up ? '↑' : '↓'} ${num1(d.abs())}', up != lowerIsBetter);
}

/// 12 → "12" · 3.25 → "3.3"
String num1(num n) => n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);
