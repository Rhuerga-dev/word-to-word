import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import 'user_profile.dart';

/// Entrar, salir y el perfil. El token se guarda cifrado (Keychain / Keystore).
class AuthRepository {
  AuthRepository(this._api, [FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final Api _api;
  final FlutterSecureStorage _storage;

  /// Recupera el token guardado. Devuelve si había uno.
  Future<bool> restoreToken() async {
    _api.token = await _storage.read(key: 'token');
    return _api.token != null;
  }

  Future<void> login(String email, String password) async =>
      _useToken(asString(asMap(await _api.post('/auth/login', {'email': email, 'password': password}))['token']));

  Future<void> demo() async => _useToken(asString(asMap(await _api.post('/auth/demo'))['token']));

  Future<UserProfile> me() async => UserProfile.fromJson(asMap(await _api.get('/me')));

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await clear();
  }

  Future<void> clear() async {
    _api.token = null;
    await _storage.delete(key: 'token');
  }

  /// Guarda el recordatorio en el servidor y devuelve el perfil actualizado.
  Future<UserProfile> saveReminder({required bool enabled, required String time, required String timezone}) async =>
      UserProfile.fromJson(asMap(await _api.put('/reminders', {'enabled': enabled, 'time': time, 'timezone': timezone})));

  Future<void> _useToken(String token) async {
    _api.token = token;
    await _storage.write(key: 'token', value: token);
  }

  set onUnauthorized(void Function() f) => _api.onUnauthorized = f;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiProvider)));
