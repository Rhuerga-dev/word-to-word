import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import '../../session/data/word_card.dart';

/// Lo que se puede practicar suelto: errores pendientes y fichas del día.
class PracticeData {
  const PracticeData({required this.mistakes, required this.cards});
  final List<Mistake> mistakes;
  final List<WordCard> cards;
}

class PracticeRepository {
  PracticeRepository(this._api);
  final Api _api;

  Future<PracticeData> fetch() async {
    final r = await Future.wait([_api.get('/speaking/mistakes'), _api.get('/today')]);
    return PracticeData(mistakes: listOf(asMap(r[0])['mistakes'], Mistake.fromJson), cards: listOf(asMap(r[1])['cards'], WordCard.fromJson));
  }
}

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) => PracticeRepository(ref.watch(apiProvider)));
