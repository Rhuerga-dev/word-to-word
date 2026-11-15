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
          final r = await Future.wait([
            _api.get('/progress'),
            _api.get('/league'),
            _api.get('/achievements'),
            _optional('/speaking/weekly'),
          ]);
          return {'progress': r[0], 'league': r[1], 'achievements': r[2], 'weekly': r[3]};
        },
        (j, _) {
          final m = asMap(j);
          return ProgressBundle(
            ProgressData.fromJson(asMap(m['progress'])),
            League.fromJson(asMap(m['league'])),
            Achievements.fromJson(asMap(m['achievements'])),
            m['weekly'] is Map ? WeeklyFluency.fromJson(asMap(m['weekly'])) : null,
          );
        },
      );

  /// Lo nuevo que un servidor viejo quizá no tiene: si falla, la pestaña se ve igual que antes (sin eso).
  Future<Object?> _optional(String path) async {
    try {
      return await _api.get(path);
    } on ApiException {
      return null;
    }
  }

  Future<void> setLeagueVisible(bool visible) => _api.put('/league/visibility', {'visible': visible});
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) => ProgressRepository(ref.watch(apiProvider), ref.watch(offlineCacheProvider)));
