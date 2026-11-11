import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/offline_cache.dart';
import '../utils/json.dart';
import 'tr.dart';

/// Traducciones de la interfaz desde el API, como en CuPay: se descargan al abrir la app, se guardan
/// para usarlas sin conexión y los textos que faltan se avisan al servidor para que los traduzca la IA.
/// El estado es la versión del diccionario: al cambiar, la app se vuelve a dibujar.
class TranslationsController extends Notifier<String> {
  final _pending = <String>{};
  final _reported = <String>{};
  Timer? _timer;

  Api get _api => ref.read(apiProvider);
  OfflineCache get _cache => ref.read(offlineCacheProvider);

  @override
  String build() {
    Lang.onMissing = _missing;
    ref.onDispose(() {
      _timer?.cancel();
      Lang.onMissing = null;
    });
    Future.microtask(_load);
    return '';
  }

  Future<void> _load() async {
    final cached = asMap(await _cache.read('i18n_en'));
    if (cached.isNotEmpty) _apply(cached);
    try {
      final d = asMap(await _api.get('/i18n/en'));
      if (asString(d['version']) != state) {
        _apply(d);
        await _cache.write('i18n_en', d);
      }
    } catch (_) {
      // Sin conexión: se queda lo guardado (o lo que trae la app).
    }
  }

  void _apply(Map<String, dynamic> d) {
    Lang.remote = {for (final e in asMap(d['strings']).entries) e.key: '${e.value}'};
    state = asString(d['version']);
  }

  /// Un texto sin traducción: se junta con otros y se avisa a los 5 s (una vez por texto).
  void _missing(String key) {
    if (!_reported.add(key)) return;
    _pending.add(key);
    _timer ??= Timer(const Duration(seconds: 5), _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    if (_api.token == null || _pending.isEmpty) return;
    final keys = _pending.take(50).toList();
    _pending.removeAll(keys);
    try {
      await _api.post('/i18n/missing', {'lang': 'en', 'keys': keys});
    } catch (_) {
      _reported.removeAll(keys); // se intentará la próxima vez que salga
    }
    if (_pending.isNotEmpty) _timer ??= Timer(const Duration(seconds: 5), _flush);
  }
}

final translationsProvider = NotifierProvider<TranslationsController, String>(TranslationsController.new);
