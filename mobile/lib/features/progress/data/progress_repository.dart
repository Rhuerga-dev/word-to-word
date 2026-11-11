import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/utils/json.dart';
import 'progress_models.dart';

class ProgressRepository {
  ProgressRepository(this._api, this._cache);
  final Api _api;
  final OfflineCache _cache;

  Future<ProgressBundle> fetch() => _cache.fetch(
        'progress',
        () async {
          final r = await Future.wait([_api.get('/progress'), _api.get('/league'), _api.get('/achievements')]);
          return {'progress': r[0], 'league': r[1], 'achievements': r[2]};
        },
        (j, _) {
          final m = asMap(j);
          return ProgressBundle(ProgressData.fromJson(asMap(m['progress'])), League.fromJson(asMap(m['league'])), Achievements.fromJson(asMap(m['achievements'])));
        },
      );

  Future<void> setLeagueVisible(bool visible) => _api.put('/league/visibility', {'visible': visible});
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) => ProgressRepository(ref.watch(apiProvider), ref.watch(offlineCacheProvider)));
