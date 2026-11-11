import '../../../core/utils/json.dart';
import '../../session/data/word_card.dart';

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
    this.offline = false,
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

  /// Viene de lo guardado (sin conexión): solo se pueden hacer las fichas.
  final bool offline;

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
      offline: offline,
    );
  }
}
