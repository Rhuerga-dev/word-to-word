import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import '../../session/data/word_card.dart';
import 'path_models.dart';

class PathRepository {
  PathRepository(this._api);
  final Api _api;

  Future<PathData> fetch() async => PathData.fromJson(asMap(await _api.get('/path')));

  /// Palabras de la unidad que aún no aprendiste (hasta 5).
  Future<List<WordCard>> unitWords(String unitId) async => listOf(asMap(await _api.get('/path/units/$unitId/words'))['cards'], WordCard.fromJson);
}

final pathRepositoryProvider = Provider<PathRepository>((ref) => PathRepository(ref.watch(apiProvider)));
