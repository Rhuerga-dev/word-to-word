import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/utils/json.dart';
import '../../session/data/word_card.dart';

/// El plan de fichas de hoy (GET /today) y las cuentas (GET /stats).
class WordsDay {
  const WordsDay({required this.dailyNew, required this.newDone, required this.cards, this.learned = 0, this.mastered = 0, this.forecast = const []});
  final int dailyNew, newDone, learned, mastered;
  final List<WordCard> cards;

  /// Repasos de los próximos 7 días: (fecha, cuántas).
  final List<(DateTime, int)> forecast;

  List<WordCard> get reviews => [for (final c in cards) if (!c.isNew) c];
  List<WordCard> get newCards => [for (final c in cards) if (c.isNew) c];
}

class WordsRepository {
  WordsRepository(this._api, this._cache);
  final Api _api;
  final OfflineCache _cache;

  Future<WordsDay> fetch() => _cache.fetch(
        'words',
        () async {
          final r = await Future.wait([_api.get('/today'), _api.get('/stats')]);
          return {'today': r[0], 'stats': r[1]};
        },
        (j, _) {
          final t = asMap(asMap(j)['today']), s = asMap(asMap(j)['stats']);
          return WordsDay(
            dailyNew: asInt(t['daily_new'], 10),
            newDone: asInt(t['new_done']),
            cards: listOf(t['cards'], WordCard.fromJson),
            learned: asInt(s['learned']),
            mastered: asInt(s['mastered']),
            forecast: [for (final f in asMaps(s['forecast'])) (DateTime.tryParse(asString(f['date'])) ?? DateTime.now(), asInt(f['count']))],
          );
        },
      );

  /// Cuántas palabras nuevas por día (1–50).
  Future<void> setDailyNew(int n) => _api.put('/settings', {'daily_new': n});

  /// Guarda tu escena AID (vacía = borrarla).
  Future<void> saveAid(int wordId, String text) => _api.put('/words/$wordId/aid', {'aid': text.trim().isEmpty ? null : text.trim()});

  /// Tres escenas cortas sugeridas por la IA.
  Future<List<String>> suggestAid(int wordId) async =>
      [for (final s in (asMap(await _api.post('/words/$wordId/aid/suggest'))['suggestions'] as List? ?? const [])) '$s'];
}

final wordsRepositoryProvider = Provider<WordsRepository>((ref) => WordsRepository(ref.watch(apiProvider), ref.watch(offlineCacheProvider)));
final wordsProvider = FutureProvider<WordsDay>((ref) => ref.watch(wordsRepositoryProvider).fetch());
