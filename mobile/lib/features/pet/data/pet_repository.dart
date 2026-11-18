import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/offline_cache.dart';
import 'pet.dart';

class PetRepository {
  PetRepository(this._api, this._cache);
  final Api _api;
  final OfflineCache _cache;

  /// La mascota, o null si no se puede saber (servidor viejo, error…): entonces la app sigue igual, sin ella.
  /// Sin conexión se enseña la última que se vio.
  Future<PetState?> fetch() async {
    try {
      return await _cache.fetch('pet', () => _api.get('/pet'), (j, _) => PetState.tryParse(j));
    } on ApiException {
      return null;
    }
  }
}

final petRepositoryProvider = Provider<PetRepository>((ref) => PetRepository(ref.watch(apiProvider), ref.watch(offlineCacheProvider)));
