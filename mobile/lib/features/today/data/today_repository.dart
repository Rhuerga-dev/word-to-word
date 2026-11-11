import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/utils/json.dart';
import 'today.dart';

class TodayRepository {
  TodayRepository(this._api, this._cache);
  final Api _api;
  final OfflineCache _cache;

  /// Primero sube lo que hiciste sin conexión; luego trae lo de hoy (o lo guardado si no hay internet).
  Future<TodayData> fetch() async {
    await _cache.flush();
    return _cache.fetch('today', () => _api.get('/session/today'), (j, offline) => TodayData.fromJson(asMap(j), offline: offline));
  }
}

final todayRepositoryProvider = Provider<TodayRepository>((ref) => TodayRepository(ref.watch(apiProvider), ref.watch(offlineCacheProvider)));
