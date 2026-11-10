import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

/// Sesión del alumno: el token se guarda cifrado en el teléfono (Keychain / Keystore).
class Auth extends ChangeNotifier {
  Auth(this.api, {FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage() {
    api.onUnauthorized = () => _clear();
  }

  final Api api;
  final FlutterSecureStorage _storage;
  Map<String, dynamic>? profile;
  Map<String, dynamic> config = {};
  bool loading = true;

  bool get loggedIn => api.token != null && profile != null;
  String get firstName {
    final n = (profile?['name'] as String? ?? '').trim().split(RegExp(r'\s+')).first;
    return ['Estudiante', 'Invitado'].contains(n) ? '' : n;
  }

  Future<void> restore() async {
    api.token = await _storage.read(key: 'token');
    if (api.token != null) {
      try {
        await _loadProfile();
      } catch (_) {
        await _clear(notify: false);
      }
    }
    loading = false;
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final results = await Future.wait([api.get('/me'), api.get('/config')]);
    profile = Map<String, dynamic>.from(results[0] as Map);
    config = Map<String, dynamic>.from(results[1] as Map);
  }

  Future<void> _clear({bool notify = true}) async {
    api.token = null;
    profile = null;
    await _storage.delete(key: 'token');
    if (notify) notifyListeners();
  }
}
