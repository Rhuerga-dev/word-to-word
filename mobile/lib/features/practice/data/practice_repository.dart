import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/utils/json.dart';
import '../../session/data/word_card.dart';

/// Lo que se puede practicar suelto: errores pendientes y fichas del día.
class PracticeData {
  const PracticeData({required this.mistakes, required this.cards});
  final List<Mistake> mistakes;
  final List<WordCard> cards;
}

class PracticeRepository {
  PracticeRepository(this._api, this._cache);
  final Api _api;
  final OfflineCache _cache;

  Future<PracticeData> fetch() => _cache.fetch(
        'practice',
        () async {
          final r = await Future.wait([_api.get('/speaking/mistakes'), _api.get('/today')]);
          return {'mistakes': asMap(r[0])['mistakes'], 'cards': asMap(r[1])['cards']};
        },
        (j, _) => PracticeData(mistakes: listOf(asMap(j)['mistakes'], Mistake.fromJson), cards: listOf(asMap(j)['cards'], WordCard.fromJson)),
      );
}

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) => PracticeRepository(ref.watch(apiProvider), ref.watch(offlineCacheProvider)));
