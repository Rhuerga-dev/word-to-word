import '../../../core/l10n/tr.dart';
import '../../../core/utils/json.dart';
import '../../session/data/word_card.dart';

class SoundProgress {
  const SoundProgress({required this.phoneme, required this.tier, required this.mastered, required this.errors});
  final String phoneme;

  /// g = Guiado · p = Práctica · d = Dominio
  final String tier;
  final bool mastered;
  final int errors;

  String get label => tr(mastered ? 'Dominado' : const {'g': 'Guiado', 'p': 'Práctica', 'd': 'Dominio'}[tier] ?? '');
}

/// GET /progress (solo lo que muestra la app).
class ProgressData {
  const ProgressData({
    required this.wordsLearned,
    required this.streak,
    required this.speakingMinutes,
    required this.speakingToday,
    required this.mistakesMastered,
    required this.mistakesByCategory,
    required this.sounds,
    required this.todo,
    this.streakFreezes = 0,
    this.streakProtected = false,
  });

  final int wordsLearned, streak, mistakesMastered;

  /// Protectores de racha (0–2): se gana uno cada 7 días seguidos y cada uno salva un día sin estudiar.
  final int streakFreezes;

  /// Faltaste algún día y un protector lo está cubriendo: hay que estudiar hoy para no perder la racha.
  final bool streakProtected;
  final double speakingMinutes, speakingToday;
  final List<(String label, int count)> mistakesByCategory;
  final List<SoundProgress> sounds;
  final List<String> todo;

  /// Los protectores de racha vienen en vocab; si faltan (servidor viejo): 0 y false.
  factory ProgressData.fromJson(Map<String, dynamic> j) {
    final v = asMap(j['vocab']), s = asMap(j['speaking']), m = asMap(j['mistakes']);
    return ProgressData(
      wordsLearned: asInt(v['learned']),
      streak: asInt(v['streak']),
      speakingMinutes: asDouble(s['total_minutes']),
      speakingToday: asDouble(s['today']),
      mistakesMastered: asInt(m['mastered']),
      mistakesByCategory: [for (final c in asMaps(m['by_category'])) (asString(c['label']), asInt(c['count']))],
      sounds: [
        for (final x in asMaps(asMap(j['pronunciation'])['sounds']))
          SoundProgress(phoneme: asString(x['phoneme']), tier: asString(x['tier'], 'g'), mastered: asBool(x['mastered']), errors: asInt(x['errors'])),
      ],
      todo: [for (final t in asMaps(j['todo'])) '${asString(t['icon'])} ${asString(t['text'])}'.trim()],
      streakFreezes: asInt(v['streak_freezes']).clamp(0, 9),
      streakProtected: asBool(v['streak_protected']),
    );
  }
}

class LeagueRow {
  const LeagueRow({required this.rank, required this.name, required this.xp, required this.me});
  final int rank, xp;
  final String name;
  final bool me;
}

/// La liga de la semana (GET /league).
class League {
  const League({required this.daysLeft, required this.visible, required this.myRank, required this.players, required this.top});
  final int daysLeft, players;
  final bool visible;
  final int? myRank;
  final List<LeagueRow> top;

  factory League.fromJson(Map<String, dynamic> j) {
    final me = asMap(j['me']);
    return League(
      daysLeft: asInt(j['days_left']),
      visible: asBool(j['visible']),
      myRank: me['rank'] == null ? null : asInt(me['rank']),
      players: asInt(j['players']),
      top: [for (final r in asMaps(j['top'])) LeagueRow(rank: asInt(r['rank']), name: asString(r['name']), xp: asInt(r['xp']), me: asBool(r['me']))],
    );
  }
}

/// Los logros (GET /achievements).
class Achievements {
  const Achievements({required this.unlocked, required this.total, required this.list});
  final int unlocked, total;
  final List<Achievement> list;

  factory Achievements.fromJson(Map<String, dynamic> j) =>
      Achievements(unlocked: asInt(j['unlocked']), total: asInt(j['total']), list: listOf(j['achievements'], Achievement.fromJson));
}

/// Números de una semana hablando (una mitad de GET /speaking/weekly). null = sin datos para medirlo.
class WeekNumbers {
  const WeekNumbers({
    this.minutes = 0,
    this.sessions = 0,
    this.days = 0,
    this.words = 0,
    this.wpm,
    this.reaction,
    this.pausesPerMin,
    this.mistakesNew = 0,
    this.mistakesMastered = 0,
  });
  final double minutes;
  final int sessions, days, words, mistakesNew, mistakesMastered;

  /// Palabras por minuto (más = más fluido).
  final int? wpm;

  /// Segundos en empezar a contestar (menos = mejor).
  final double? reaction;

  /// Pausas largas por minuto (menos = mejor).
  final double? pausesPerMin;

  /// No habló nada esa semana.
  bool get empty => minutes <= 0 && sessions == 0 && words == 0;

  factory WeekNumbers.fromJson(Map<String, dynamic> j) => WeekNumbers(
        minutes: asDouble(j['minutes']),
        sessions: asInt(j['sessions']),
        days: asInt(j['days']),
        words: asInt(j['words']),
        wpm: j['wpm'] == null ? null : asInt(j['wpm']),
        reaction: j['reaction'] == null ? null : asDouble(j['reaction']),
        pausesPerMin: j['pauses_per_min'] == null ? null : asDouble(j['pauses_per_min']),
        mistakesNew: asInt(j['mistakes_new']),
        mistakesMastered: asInt(j['mistakes_mastered']),
      );
}

/// Informe de la semana hablando (GET /speaking/weekly): estos 7 días contra los 7 anteriores.
class WeeklyFluency {
  const WeeklyFluency({this.from = '', this.to = '', this.now = const WeekNumbers(), this.before = const WeekNumbers(), this.conquered = const []});
  final String from, to;
  final WeekNumbers now, before;

  /// Errores que ya no cometes (lo que decías → lo correcto).
  final List<(String said, String correct)> conquered;

  factory WeeklyFluency.fromJson(Map<String, dynamic> j) => WeeklyFluency(
        from: asString(j['from']),
        to: asString(j['to']),
        now: WeekNumbers.fromJson(asMap(j['now'])),
        before: WeekNumbers.fromJson(asMap(j['before'])),
        conquered: [
          for (final c in asMaps(j['conquered']))
            if (asString(c['said']).isNotEmpty) (asString(c['said']), asString(c['correct'])),
        ],
      );
}

/// Todo lo de la pestaña Progreso.
class ProgressBundle {
  const ProgressBundle(this.progress, this.league, this.achievements, [this.weekly]);
  final ProgressData progress;
  final League league;
  final Achievements achievements;

  /// null si el servidor aún no tiene el informe semanal.
  final WeeklyFluency? weekly;
}
