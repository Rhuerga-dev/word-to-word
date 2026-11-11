/// Dos palabras por sonido difícil (las mismas ideas que el Taller de la web).
const soundWords = <String, List<String>>{
  'θ': ['think', 'three'], 'ð': ['this', 'mother'], 'v': ['very', 'voice'], 'ɪ': ['ship', 'sit'], 'i': ['sheep', 'seat'],
  'æ': ['cat', 'apple'], 'ʌ': ['cup', 'money'], 'z': ['zoo', 'easy'], 'ʃ': ['she', 'shop'], 'ɹ': ['red', 'right'],
  'h': ['house', 'hello'], 'ɜ': ['work', 'bird'], 'oʊ': ['go', 'phone'], 'ʒ': ['usual', 'vision'], 'ŋ': ['thing', 'morning'],
};
String? soundKey(String p) {
  final k = p.replaceAll('ː', '');
  if (k == 'r') return 'ɹ';
  if (k == 'ɝ' || k == 'ɚ') return 'ɜ';
  return soundWords.containsKey(k) ? k : null;
}

sealed class SessionStep {}

class ReviewStep extends SessionStep {
  ReviewStep(this.card);
  final Map card;
}

class NewStep extends SessionStep {
  NewStep(this.card);
  final Map card;
}

class SoundStep extends SessionStep {
  SoundStep(this.phoneme, this.word);
  final String phoneme, word;
}

class NarrateStep extends SessionStep {}

class MistakeStep extends SessionStep {
  MistakeStep(this.mistake);
  final Map mistake;
}

/// Lo que toca hoy (de GET /session/today), en orden.
class SessionPlan {
  SessionPlan(this.steps, {this.title, this.daily = true});
  final List<SessionStep> steps;
  final String? title;
  final bool daily; // la sesión de Hoy (al final se registra y da bono)

  factory SessionPlan.fromToday(Map<String, dynamic> d) {
    final plan = d['plan'] as Map;
    final steps = <SessionStep>[
      for (final c in plan['reviews'] as List) ReviewStep(c as Map),
      for (final c in plan['new'] as List) NewStep(c as Map),
    ];
    final sounds = (plan['sounds'] as List).map((s) => soundKey(s['phoneme'] as String)).whereType<String>().toList();
    final ph = sounds.isNotEmpty ? sounds.first : const ['θ', 'v', 'ɪ', 'æ', 'z'][DateTime.now().day % 5];
    for (final w in soundWords[ph]!) {
      steps.add(SoundStep(ph, w));
    }
    steps.add(NarrateStep()); // por ahora la app hace la narración; foto y shadowing llegan después
    for (final m in plan['mistakes'] as List) {
      steps.add(MistakeStep(m as Map));
    }
    return SessionPlan(steps);
  }
}
