import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

/// Actualizaciones dentro de la app (Google Play, modo flexible): al abrir W2W pregunta a Play si hay versión
/// nueva; si la hay, se ofrece un aviso, se descarga mientras sigues usando la app y luego se reinicia.
/// Solo funciona si la app se instaló desde Play (en el emulador o con un APK suelto no hace nada).
enum UpdateStage { none, available, downloading, ready }

class AppUpdateController extends Notifier<UpdateStage> {
  bool _checked = false;

  @override
  UpdateStage build() => UpdateStage.none;

  /// Se llama al entrar en la app. Una sola vez por arranque.
  Future<void> check() async {
    if (_checked || !Platform.isAndroid) return;
    _checked = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.installStatus == InstallStatus.downloaded) {
        state = UpdateStage.ready;
      } else if (info.updateAvailability == UpdateAvailability.updateAvailable && info.flexibleUpdateAllowed) {
        state = UpdateStage.available;
      }
    } catch (_) {
      // Sin Play (APK de pruebas, emulador) o sin conexión: no pasa nada.
    }
  }

  /// "Actualizar": descarga en segundo plano.
  Future<void> download() async {
    if (state != UpdateStage.available) return;
    state = UpdateStage.downloading;
    try {
      final r = await InAppUpdate.startFlexibleUpdate();
      state = r == AppUpdateResult.success ? UpdateStage.ready : UpdateStage.available;
    } catch (_) {
      state = UpdateStage.available;
    }
  }

  /// "Reiniciar": instala lo descargado (la app se cierra y vuelve a abrirse).
  Future<void> install() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {}
  }

  void dismiss() => state = UpdateStage.none;
}

final appUpdateProvider = NotifierProvider<AppUpdateController, UpdateStage>(AppUpdateController.new);
