import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import 'progress_models.dart';

class ProgressRepository {
  ProgressRepository(this._api);
  final Api _api;

  Future<ProgressBundle> fetch() async {
    final r = await Future.wait([_api.get('/progress'), _api.get('/league'), _api.get('/achievements')]);
    return ProgressBundle(ProgressData.fromJson(asMap(r[0])), League.fromJson(asMap(r[1])), Achievements.fromJson(asMap(r[2])));
  }

  Future<void> setLeagueVisible(bool visible) => _api.put('/league/visibility', {'visible': visible});
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) => ProgressRepository(ref.watch(apiProvider)));
