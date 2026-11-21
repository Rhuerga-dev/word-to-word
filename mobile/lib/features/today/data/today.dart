import '../../../core/utils/json.dart';
import '../../session/data/word_card.dart';
import '../../session/data/ear_item.dart';

/// Puntos de hoy y de la semana.
class XpToday {
  const XpToday({required this.xp, required this.goal, required this.total, required this.sessions, required this.week});
  final int xp;
  final int goal;
  final int total;
  final int sessions;
  final List<int> week;

  int get weekTotal => week.fold(0, (a, b) => a + b);
  bool get goalMet => xp >= goal;

  factory XpToday.fromJson(Map<String, dynamic> j) => XpToday(
        xp: asInt(j['xp']),
        goal: asInt(j['goal'], 100),
        total: asInt(j['total']),
        sessions: asInt(j['sessions']),
        week: [for (final d in asMaps(j['week'])) asInt(d['xp'])],
      );
}

/// Lo que toca hoy (GET /session/today).
class TodayData {
  const TodayData({
    required this.xp,
    required this.streak,
    required this.minutes,
    required this.reviews,
    required this.newCards,
    required this.sounds,
    required this.speak,
    required this.mistakes,
    this.ear = const [],
    this.offline = false,
    this.steps,
    this.newPaused = false,
    this.reviewsDue = 0,
    this.newPauseAt = 0,
  });

  final XpToday xp;
  final int streak;
  final double minutes;
  final List<WordCard> reviews;
  final List<WordCard> newCards;

  /// Sonidos débiles, el peor primero (fonemas IPA).
  final List<String> sounds;

  /// narrate · picture · shadowing
  final String speak;
  final List<Mistake> mistakes;

  /// Oído: palabras que ya aprendiste para reconocerlas al escucharlas (el primer paso).
  final List<EarItem> ear;

  /// Los pasos que tiene la clase en este curso (ear, reviews, new, sound, narrate, shadowing, mistakes).
  /// null = todos, como siempre (curso de inglés o servidor viejo).
  final Set<String>? steps;

  /// ¿La clase de este curso tiene ese paso?
  bool has(String step) => steps == null || steps!.contains(step);

  /// Viene de lo guardado (sin conexión): solo se pueden hacer las fichas.
  final bool offline;

  /// Hoy no hay palabras nuevas porque hay demasiados repasos atrasados ([reviewsDue]); vuelven con [newPauseAt] o menos.
  final bool newPaused;
  final int reviewsDue;
  final int newPauseAt;

  bool get studied => xp.xp > 0;

  factory TodayData.fromJson(Map<String, dynamic> j, {bool offline = false}) {
    final plan = asMap(j['plan']);
    return TodayData(
      xp: XpToday.fromJson(asMap(j['xp'])),
      streak: asInt(j['streak']),
      minutes: asDouble(j['minutes']),
      reviews: listOf(plan['reviews'], WordCard.fromJson),
      newCards: listOf(plan['new'], WordCard.fromJson),
      sounds: [for (final s in asMaps(plan['sounds'])) asString(s['phoneme'])],
      speak: asString(plan['speak'], 'narrate'),
      mistakes: listOf(plan['mistakes'], Mistake.fromJson),
      ear: listOf(plan['ear'], EarItem.fromJson),
      offline: offline,
      steps: plan['steps'] is List ? {for (final x in plan['steps'] as List) if (x is String) x} : null,
      newPaused: j['new_paused'] == true,
      reviewsDue: asInt(j['reviews_due']),
      newPauseAt: asInt(j['new_pause_at']),
    );
  }
}
