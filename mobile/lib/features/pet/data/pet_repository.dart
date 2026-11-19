import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/utils/json.dart';
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

  /// Le pone nombre a la mascota ([name] null = «luego»: se queda como Brainy, pero ya presentada).
  /// Devuelve la mascota como quedó. Si el nombre no vale, lanza [ApiException] con el mensaje del servidor.
  Future<PetState?> rename(String? name) async {
    final json = await _api.put('/pet/name', {'name': name});
    final pet = PetState.tryParse(json);
    if (pet != null) {
      // Lo guardado sin conexión ya lleva el nombre nuevo. No se espera: guardar en disco no debe frenar la pantalla.
      unawaited(_cache.write('pet', json).catchError((Object _) {}));
    }
    return pet;
  }

  /// Cambia el color de la mascota ([color] = clave de la lista fija; null = volver al neutro).
  Future<PetState?> recolor(String? color) async {
    final json = await _api.put('/pet/color', {'color': color});
    final pet = PetState.tryParse(json);
    if (pet != null) unawaited(_cache.write('pet', json).catchError((Object _) {}));
    return pet;
  }

  /// Un botón de cuidado: el servidor dice qué ejercicio toca (new · reviews · ear · mistakes · sound) o '' si
  /// ahora no hay nada que hacer. null = no se pudo preguntar (sin conexión, servidor viejo): decide la app.
  Future<String?> act(PetAction action) async {
    try {
      final r = asMap(await _api.post('/pet/${action.name}'));
      if (!r.containsKey('go')) return null;
      return asString(r['go']);
    } on ApiException {
      return null;
    }
  }
}

final petRepositoryProvider = Provider<PetRepository>((ref) => PetRepository(ref.watch(apiProvider), ref.watch(offlineCacheProvider)));
