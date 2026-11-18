import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ajuste «Modo Brainy» (por defecto, NO): la pantalla principal es la mascota y cuidarla es estudiar.
/// Se guarda en el teléfono. Apagado, la app queda exactamente como siempre.
class BrainyModeSetting extends AsyncNotifier<bool> {
  static const key = 'brainy_mode';
  static const _storage = FlutterSecureStorage();

  @override
  Future<bool> build() async {
    try {
      return (await _storage.read(key: key)) == '1';
    } catch (_) {
      return false;
    }
  }

  Future<void> set(bool on) async {
    state = AsyncData(on);
    try {
      await _storage.write(key: key, value: on ? '1' : '0');
    } catch (_) {}
  }
}

final brainyModeProvider = AsyncNotifierProvider<BrainyModeSetting, bool>(BrainyModeSetting.new);
