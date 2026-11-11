import '../../../core/utils/json.dart';
import '../../session/data/word_card.dart';

class SoundProgress {
  const SoundProgress({required this.phoneme, required this.tier, required this.mastered, required this.errors});
  final String phoneme;

  /// g = Guiado · p = Práctica · d = Dominio
  final String tier;
  final bool mastered;
  final int errors;

  String get label => mastered ? 'Dominado' : const {'g': 'Guiado', 'p': 'Práctica', 'd': 'Dominio'}[tier] ?? '';
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
  });

  final int wordsLearned, streak, mistakesMastered;
  final double speakingMinutes, speakingToday;
  final List<(String label, int count)> mistakesByCategory;
  final List<SoundProgress> sounds;
  final List<String> todo;

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

/// Todo lo de la pestaña Progreso.
class ProgressBundle {
  const ProgressBundle(this.progress, this.league, this.achievements);
  final ProgressData progress;
  final League league;
  final Achievements achievements;
}
