import '../../today/data/today.dart';
import 'word_card.dart';
import '../../../core/l10n/tr.dart';
import 'ear_item.dart';

/// Dos palabras por sonido difícil (las mismas ideas que el Taller de la web).
const soundWords = <String, List<String>>{
  'θ': ['think', 'three'], 'ð': ['this', 'mother'], 'v': ['very', 'voice'], 'ɪ': ['ship', 'sit'], 'i': ['sheep', 'seat'],
  'æ': ['cat', 'apple'], 'ʌ': ['cup', 'money'], 'z': ['zoo', 'easy'], 'ʃ': ['she', 'shop'], 'ɹ': ['red', 'right'],
  'h': ['house', 'hello'], 'ɜ': ['work', 'bird'], 'oʊ': ['go', 'phone'], 'ʒ': ['usual', 'vision'], 'ŋ': ['thing', 'morning'],
};

/// Normaliza el fonema del servidor a una clave de [soundWords] (o null si no hay ejercicio).
String? soundKey(String p) {
  final k = p.replaceAll('ː', '');
  if (k == 'r') return 'ɹ';
  if (k == 'ɝ' || k == 'ɚ') return 'ɜ';
  return soundWords.containsKey(k) ? k : null;
}

/// Sonido del día cuando no hay uno débil registrado.
String defaultSound([DateTime? now]) => const ['θ', 'v', 'ɪ', 'æ', 'z'][(now ?? DateTime.now()).day % 5];

sealed class SessionStep {
  const SessionStep();
}

/// Oído: oír una palabra aprendida (sin verla) y elegir qué significa, rápido.
class EarStep extends SessionStep {
  const EarStep(this.item);
  final EarItem item;
}

class ReviewStep extends SessionStep {
  const ReviewStep(this.card);
  final WordCard card;
}

class NewStep extends SessionStep {
  const NewStep(this.card);
  final WordCard card;
}

class SoundStep extends SessionStep {
  const SoundStep(this.phoneme, this.word);
  final String phoneme, word;
}

class NarrateStep extends SessionStep {
  const NarrateStep();
}

class MistakeStep extends SessionStep {
  const MistakeStep(this.mistake);
  final Mistake mistake;
}

/// Los ejercicios de una sesión, en orden.
class SessionPlan {
  const SessionPlan(this.steps, {this.title, this.daily = false});
  final List<SessionStep> steps;
  final String? title;

  /// La sesión de Hoy: al final se registra y da bono.
  final bool daily;

  factory SessionPlan.fromToday(TodayData d) {
    final ph = d.sounds.map(soundKey).whereType<String>().firstOrNull ?? defaultSound();
    return SessionPlan([
      // Primero el oído, con la cabeza fresca.
      for (final e in d.ear) EarStep(e),
      for (final c in d.reviews) ReviewStep(c),
      for (final c in d.newCards) NewStep(c),
      for (final w in soundWords[ph]!) SoundStep(ph, w),
      const NarrateStep(), // por ahora la app hace la narración; foto y shadowing llegan después
      for (final m in d.mistakes) MistakeStep(m),
    ], daily: true);
  }

  /// Sin conexión: solo las fichas (lo demás necesita el servidor para escucharte).
  factory SessionPlan.offline(TodayData d) {
    return SessionPlan([for (final c in d.reviews) ReviewStep(c), for (final c in d.newCards) NewStep(c)], title: tr('Fichas sin conexión'));
  }

  static SessionPlan sound(String phoneme, {String? title}) =>
      SessionPlan([for (final w in soundWords[phoneme]!) SoundStep(phoneme, w)], title: title);
}
