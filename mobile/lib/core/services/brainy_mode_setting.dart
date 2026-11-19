import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/presentation/auth_controller.dart';

/// Lo que el servidor propone para este alumno (experimento A/B, `brainy_default` de GET /me).
/// null = sin experimento o servidor viejo: el Modo Brainy nace apagado, como siempre.
final brainyServerDefaultProvider = Provider<bool?>((ref) => ref.watch(authControllerProvider).valueOrNull?.brainyDefault);

/// Ajuste «Modo Brainy»: la pantalla principal es la mascota y cuidarla es estudiar.
///
/// - Si el alumno NUNCA tocó el interruptor, vale lo que proponga el servidor (o apagado si no propone nada).
/// - Si lo tocó, manda siempre su elección: se guarda en el teléfono y el servidor ya no la cambia.
///
/// En el teléfono solo se guarda algo cuando el alumno toca el interruptor: por eso «hay algo guardado»
/// significa «lo cambió a mano» ([changed]).
class BrainyModeSetting extends AsyncNotifier<bool> {
  static const key = 'brainy_mode';
  static const _storage = FlutterSecureStorage();

  bool _changed = false;

  /// ¿El alumno eligió el modo a mano alguna vez?
  bool get changed => _changed;

  /// Lo guardado en el teléfono: '1', '0' o null si nunca lo tocó. (Los tests lo sustituyen.)
  Future<String?> readStored() => _storage.read(key: key);
  Future<void> writeStored(String value) => _storage.write(key: key, value: value);

  @override
  Future<bool> build() async {
    final serverDefault = ref.watch(brainyServerDefaultProvider);
    String? stored;
    try {
      stored = await readStored();
    } catch (_) {}
    _changed = stored == '1' || stored == '0';
    return _changed ? stored == '1' : (serverDefault ?? false);
  }

  Future<void> set(bool on) async {
    _changed = true;
    state = AsyncData(on);
    try {
      await writeStored(on ? '1' : '0');
    } catch (_) {}
  }
}

final brainyModeProvider = AsyncNotifierProvider<BrainyModeSetting, bool>(BrainyModeSetting.new);
