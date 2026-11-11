import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/utils/json.dart';
import '../../session/data/word_card.dart';
import 'path_models.dart';

class PathRepository {
  PathRepository(this._api, this._cache);
  final Api _api;
  final OfflineCache _cache;

  Future<PathData> fetch() => _cache.fetch('path', () => _api.get('/path'), (j, _) => PathData.fromJson(asMap(j)));

  /// Palabras de la unidad que aún no aprendiste (hasta 5).
  Future<List<WordCard>> unitWords(String unitId) async => listOf(asMap(await _api.get('/path/units/$unitId/words'))['cards'], WordCard.fromJson);
}

final pathRepositoryProvider = Provider<PathRepository>((ref) => PathRepository(ref.watch(apiProvider), ref.watch(offlineCacheProvider)));
