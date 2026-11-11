import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import 'api.dart';

/// Sesión del alumno: el token se guarda cifrado en el teléfono (Keychain / Keystore).
class Auth extends GetxController {
  Auth(this.api, {FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage() {
    api.onUnauthorized = () => _clear();
  }

  final Api api;
  final FlutterSecureStorage _storage;
  final profile = Rxn<Map<String, dynamic>>();
  Map<String, dynamic> config = {};
  final loading = true.obs;

  bool get loggedIn => api.token != null && profile.value != null;
  String get firstName {
    final n = (profile.value?['name'] as String? ?? '').trim().split(RegExp(r'\s+')).first;
    return ['Estudiante', 'Invitado'].contains(n) ? '' : n;
  }

  @override
  void onInit() {
    super.onInit();
    restore();
  }

  Future<void> restore() async {
    api.token = await _storage.read(key: 'token');
    if (api.token != null) {
      try {
        await _loadProfile();
      } catch (_) {
        await _clear();
      }
    }
    loading.value = false;
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
