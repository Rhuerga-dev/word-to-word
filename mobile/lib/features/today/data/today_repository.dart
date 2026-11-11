import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import 'today.dart';

class TodayRepository {
  TodayRepository(this._api);
  final Api _api;

  Future<TodayData> fetch() async => TodayData.fromJson(asMap(await _api.get('/session/today')));
}

final todayRepositoryProvider = Provider<TodayRepository>((ref) => TodayRepository(ref.watch(apiProvider)));
