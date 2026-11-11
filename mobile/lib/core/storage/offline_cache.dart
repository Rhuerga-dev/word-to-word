import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';

/// true mientras lo que se ve viene de lo guardado (sin conexión).
final offlineProvider = StateProvider<bool>((ref) => false);

/// Caché sin conexión: guarda la última respuesta de cada pantalla y una cola de lo que hiciste sin internet
/// (notas de fichas, palabras aprendidas) para subirlo en orden al volver.
class OfflineCache {
  OfflineCache(this._api, {Future<Directory> Function()? dir, void Function(bool offline)? onOffline})
      : _dirFn = dir ?? getApplicationSupportDirectory,
        _onOffline = onOffline ?? ((_) {});

  final Api _api;
  final Future<Directory> Function() _dirFn;
  final void Function(bool) _onOffline;
  Directory? _dir;

  Future<File> _file(String name) async {
    _dir ??= Directory('${(await _dirFn()).path}/w2w_cache');
    if (!await _dir!.exists()) await _dir!.create(recursive: true);
    return File('${_dir!.path}/$name.json');
  }

  Future<void> write(String key, Object? json) async => (await _file(key)).writeAsString(jsonEncode(json));

  Future<Object?> read(String key) async {
    final f = await _file(key);
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// Pide al API; si funciona lo guarda, y si no hay conexión devuelve lo guardado.
  Future<T> fetch<T>(String key, Future<Object?> Function() get, T Function(Object? json, bool fromCache) parse) async {
    try {
      final json = await get();
      await write(key, json);
      _onOffline(false);
      return parse(json, false);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      final saved = await read(key);
      if (saved == null) rethrow;
      _onOffline(true);
      return parse(saved, true);
    }
  }

  // ---------- Cola de cambios hechos sin conexión ----------

  Future<List<Map<String, dynamic>>> pending() async =>
      [for (final e in (await read('queue') as List? ?? const [])) Map<String, dynamic>.from(e as Map)];

  Future<void> enqueue(String path, Map<String, dynamic>? body) async => write('queue', [...await pending(), {'path': path, 'body': body}]);

  /// Envía lo pendiente en orden (POST). Se detiene en el primer fallo de red; lo rechazado por el servidor se descarta.
  Future<int> flush() async {
    final items = await pending();
    var sent = 0;
    for (final it in items) {
      try {
        await _api.post(it['path'] as String, it['body'] == null ? null : Map<String, dynamic>.from(it['body'] as Map));
      } on ApiException catch (e) {
        if (e.isNetwork) break;
      }
      sent++;
    }
    if (sent > 0) await write('queue', items.sublist(sent));
    return sent;
  }
}

final offlineCacheProvider = Provider<OfflineCache>(
  (ref) => OfflineCache(ref.watch(apiProvider), onOffline: (v) => ref.read(offlineProvider.notifier).state = v),
);
