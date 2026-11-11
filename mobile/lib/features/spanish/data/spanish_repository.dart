import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/user_profile.dart';

/// La escalera de español en el servidor: cuántas veces pides español y en qué escalón estás.
class SpanishRepository {
  SpanishRepository(this._api);
  final Api _api;

  Future<SpanishInfo> fetch() async => SpanishInfo.fromJson(asMap(await _api.get('/spanish')));

  /// Escalón fijo (1–4) o null para automático.
  Future<SpanishInfo> setStep(int? step) async => SpanishInfo.fromJson(asMap(await _api.put('/spanish', {'step': step})));

  /// Cuenta un uso del español (traducción, pista…). Lanza ApiException (429) si ya no quedan.
  Future<void> use(String kind) => _api.post('/spanish/use', {'kind': kind});

  /// Traduce al español un texto del coach (cuenta como uso).
  Future<String> translate(String text) async => asString(asMap(await _api.post('/spanish/translate', {'text': text}))['text']);
}

final spanishRepositoryProvider = Provider<SpanishRepository>((ref) => SpanishRepository(ref.watch(apiProvider)));
