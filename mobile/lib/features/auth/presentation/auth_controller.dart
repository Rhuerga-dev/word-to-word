import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/reminder_service.dart';
import '../data/auth_repository.dart';
import '../data/user_profile.dart';

/// Quién tiene la sesión: null = nadie (pantalla de entrar). El router escucha este estado.
class AuthController extends AsyncNotifier<UserProfile?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<UserProfile?> build() async {
    // Si el servidor dice que el token ya no vale, se vuelve a entrar.
    _repo.onUnauthorized = () {
      _repo.clear();
      state = const AsyncData(null);
    };
    if (!await _repo.restoreToken()) return null;
    try {
      return await _repo.me();
    } catch (_) {
      await _repo.clear();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    await _repo.login(email, password);
    state = AsyncData(await _repo.me());
  }

  Future<void> demo() async {
    await _repo.demo();
    state = AsyncData(await _repo.me());
  }

  /// Borra la cuenta: se cancelan los recordatorios y se vuelve a la pantalla de entrar.
  Future<void> deleteAccount(String password) async {
    await _repo.deleteAccount(password);
    await ref.read(reminderServiceProvider).cancelAll();
    state = const AsyncData(null);
  }

  Future<void> logout() async {
    await ref.read(reminderServiceProvider).cancelAll();
    await _repo.logout();
    state = const AsyncData(null);
  }

  Future<void> saveReminder({required bool enabled, required String time, required String timezone}) async {
    state = AsyncData(await _repo.saveReminder(enabled: enabled, time: time, timezone: timezone));
  }

  /// Vuelve a pedir el perfil (por ejemplo, tras cambiar el escalón de español).
  Future<void> refreshProfile() async {
    final p = await _repo.me();
    state = AsyncData(p);
  }

  /// Actualiza solo la escalera de español (contador de usos, escalón).
  void setSpanish(SpanishInfo s) {
    final p = state.valueOrNull;
    if (p != null) state = AsyncData(p.withSpanish(s));
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, UserProfile?>(AuthController.new);

/// La escalera de español del alumno (escalón 1 si aún no hay sesión).
final spanishProvider = Provider<SpanishInfo>((ref) => ref.watch(authControllerProvider).valueOrNull?.spanish ?? const SpanishInfo());
