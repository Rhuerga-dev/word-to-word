import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AirPods (solo Android): apaga la "detección de conversación" mientras practicas, para que la
/// cancelación de ruido no se quite cada vez que hablas, y al terminar la deja como estaba.
/// En teléfonos que todavía no lo permiten (Android anterior a 16 QPR3 en casi todas las marcas)
/// no hace nada y la práctica sigue igual. Es opcional: se activa en Progreso.
class AirPodsService extends Notifier<bool> {
  static const _channel = MethodChannel('w2w/airpods');
  static const _key = 'airpods_quiet';
  final _storage = const FlutterSecureStorage();
  bool _quiet = false;

  /// Solo tiene sentido en Android (en el iPhone se hace desde el Centro de control).
  static bool get supported => Platform.isAndroid;

  @override
  bool build() {
    if (supported) {
      _storage.read(key: _key).then((v) {
        state = v == '1';
      }).catchError((_) {});
    }
    return false;
  }

  /// Activar la opción (pide el permiso de Bluetooth).
  Future<AirPodsEnable> setEnabled(bool on) async {
    if (!supported) return AirPodsEnable.unsupported;
    if (on) {
      try {
        final granted = await _channel.invokeMethod<bool>('permission') ?? false;
        if (!granted) return AirPodsEnable.denied;
      } on MissingPluginException {
        // El código nativo nuevo no está en la app instalada (se hizo hot reload): hay que reinstalarla.
        return AirPodsEnable.reinstall;
      } catch (_) {
        return AirPodsEnable.denied;
      }
    }
    state = on;
    try {
      await _storage.write(key: _key, value: on ? '1' : '0');
    } catch (_) {}
    return AirPodsEnable.ok;
  }

  /// Abre los ajustes de la app (Permisos → Dispositivos cercanos).
  Future<void> openSettings() async => _invoke<bool>('settings');

  /// Abre los ajustes de Bluetooth del teléfono (para conectar los auriculares). Solo Android.
  Future<void> openBluetooth() async => _invoke<bool>('bluetooth');

  /// ¿Hay AirPods conectados ahora?
  Future<bool> connected() async => (await _invoke<bool>('connected')) ?? false;

  /// Al empezar a practicar. Devuelve true si los AirPods aceptaron la orden.
  Future<bool> sessionStarted() async {
    if (!supported || !state || _quiet) return false;
    _quiet = (await _invoke<bool>('quiet', {'on': true})) ?? false;
    return _quiet;
  }

  /// Al terminar: la deja como estaba.
  Future<void> sessionEnded() async {
    if (!_quiet) return;
    _quiet = false;
    await _invoke<bool>('quiet', {'on': false});
  }

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (_) {
      return null; // teléfono sin soporte: no pasa nada
    }
  }
}

/// Resultado de activar la opción.
enum AirPodsEnable { ok, denied, reinstall, unsupported }

final airPodsProvider = NotifierProvider<AirPodsService, bool>(AirPodsService.new);
