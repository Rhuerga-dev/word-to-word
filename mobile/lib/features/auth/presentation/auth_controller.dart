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

  Future<void> logout() async {
    await ref.read(reminderServiceProvider).cancelAll();
    await _repo.logout();
    state = const AsyncData(null);
  }

  Future<void> saveReminder({required bool enabled, required String time, required String timezone}) async {
    state = AsyncData(await _repo.saveReminder(enabled: enabled, time: time, timezone: timezone));
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, UserProfile?>(AuthController.new);
