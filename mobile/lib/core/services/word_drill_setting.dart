import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ajuste «Practicar la palabra que fallo» (por defecto, sí). Se guarda en el teléfono.
class WordDrillSetting extends AsyncNotifier<bool> {
  static const key = 'word_drill';
  static const _storage = FlutterSecureStorage();

  @override
  Future<bool> build() async {
    try {
      return (await _storage.read(key: key)) != '0';
    } catch (_) {
      return true;
    }
  }

  Future<void> set(bool on) async {
    state = AsyncData(on);
    try {
      await _storage.write(key: key, value: on ? '1' : '0');
    } catch (_) {}
  }
}

final wordDrillSettingProvider = AsyncNotifierProvider<WordDrillSetting, bool>(WordDrillSetting.new);

/// Lo que hay ahora (mientras carga, sí).
bool wordDrillOn(Ref ref) => ref.read(wordDrillSettingProvider).valueOrNull ?? true;
