import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../providers/api_client.dart';

/// Sesión del alumno: el token se guarda cifrado en el teléfono (Keychain / Keystore).
class AuthService extends GetxService {
  AuthService(this.api, {FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage() {
    api.onUnauthorized = () => _clear();
  }

  final Api api;
  final FlutterSecureStorage _storage;
  final profile = Rxn<Map<String, dynamic>>();
  Map<String, dynamic> config = {};

  /// Lee primero [profile] (observable) para que Obx siempre se suscriba a él.
  bool get loggedIn => profile.value != null && api.token != null;

  String get firstName {
    final n = (profile.value?['name'] as String? ?? '').trim().split(RegExp(r'\s+')).first;
    return ['Estudiante', 'Invitado'].contains(n) ? '' : n;
  }

  @override
  void onInit() {
    super.onInit();
    // Si la sesión se cierra (Salir o token caducado), vuelve al login desde cualquier pantalla.
    ever<Map<String, dynamic>?>(profile, (p) {
      if (p == null && Get.currentRoute != Routes.login && Get.currentRoute != Routes.splash) Get.offAllNamed(Routes.login);
    });
  }

  /// Recupera la sesión guardada. Devuelve si quedó dentro.
  Future<bool> restore() async {
    api.token = await _storage.read(key: 'token');
    if (api.token != null) {
      try {
        await _loadProfile();
      } catch (_) {
        await _clear();
      }
    }
    return loggedIn;
  }

  Future<void> login(String email, String password) async {
    final r = await api.post('/auth/login', {'email': email, 'password': password});
    await _useToken(r['token'] as String);
  }

  Future<void> demo() async {
    final r = await api.post('/auth/demo');
    await _useToken(r['token'] as String);
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await _clear();
  }

  Future<void> _useToken(String token) async {
    api.token = token;
    await _storage.write(key: 'token', value: token);
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    final results = await Future.wait([api.get('/me'), api.get('/config')]);
    config = Map<String, dynamic>.from(results[1] as Map);
    profile.value = Map<String, dynamic>.from(results[0] as Map);
  }

  Future<void> _clear() async {
    api.token = null;
    profile.value = null;
    await _storage.delete(key: 'token');
  }
}
