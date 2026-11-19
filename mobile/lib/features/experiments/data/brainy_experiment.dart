import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/brainy_mode_setting.dart';

/// Experimento A/B del Modo Brainy: la app le cuenta al servidor el modo que de verdad usa el alumno
/// (`POST /experiments/brainy`). Si falla (sin conexión, servidor viejo…), no pasa nada: se ignora.
class BrainyExperimentRepository {
  BrainyExperimentRepository(this._api);
  final Api _api;

  /// Lo último que se envió con éxito en este arranque: no se repite lo mismo.
  (bool, bool)? _sent;

  /// Informa del modo ([mode] encendido/apagado) y de si el alumno lo cambió a mano.
  Future<void> report({required bool mode, required bool changed}) async {
    if (_sent == (mode, changed)) return;
    if (await _post({'mode': mode, 'changed': changed})) _sent = (mode, changed);
  }

  /// El alumno acaba de abrir la pantalla de Brainy.
  Future<void> opened({required bool mode, required bool changed}) => _post({'mode': mode, 'changed': changed, 'opened': true});

  Future<bool> _post(Map<String, dynamic> body) async {
    try {
      await _api.post('/experiments/brainy', body);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final brainyExperimentRepositoryProvider = Provider<BrainyExperimentRepository>((ref) => BrainyExperimentRepository(ref.watch(apiProvider)));

/// Mantiene al servidor al día: informa al entrar y cada vez que cambia el modo.
/// Sin experimento (el servidor no manda `brainy_default`) no envía nada.
final brainyExperimentReporterProvider = Provider<void>((ref) {
  if (ref.watch(brainyServerDefaultProvider) == null) return;
  final mode = ref.watch(brainyModeProvider).valueOrNull;
  if (mode == null) return;
  final changed = ref.read(brainyModeProvider.notifier).changed;
  ref.read(brainyExperimentRepositoryProvider).report(mode: mode, changed: changed);
});

/// Envuelve una pantalla de Brainy: al abrirse, lo cuenta para el experimento (una vez por apertura).
class BrainyOpened extends ConsumerStatefulWidget {
  const BrainyOpened({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<BrainyOpened> createState() => _BrainyOpenedState();
}

class _BrainyOpenedState extends ConsumerState<BrainyOpened> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(brainyServerDefaultProvider) == null) return;
      final mode = ref.read(brainyModeProvider).valueOrNull;
      if (mode == null) return;
      ref.read(brainyExperimentRepositoryProvider).opened(mode: mode, changed: ref.read(brainyModeProvider.notifier).changed);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
