import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/path/presentation/path_page.dart';
import '../../features/practice/presentation/practice_page.dart';
import '../../features/progress/presentation/progress_page.dart';
import '../../features/session/data/session_plan.dart';
import '../../features/session/presentation/session_page.dart';
import '../../features/today/presentation/today_page.dart';
import 'routes.dart';

/// Decide a dónde va cada ruta según la sesión. Pura, para poder probarla sin pantallas.
String? authRedirect({required bool loading, required bool loggedIn, required String location}) {
  if (loading) return location == Routes.splash ? null : Routes.splash;
  if (!loggedIn) return location == Routes.login ? null : Routes.login;
  if (location == Routes.login || location == Routes.splash) return Routes.today;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Cuando cambia la sesión (entrar, salir, token caducado), el router vuelve a decidir.
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);
  final rootKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.today,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return authRedirect(loading: auth.isLoading && !auth.hasValue, loggedIn: auth.valueOrNull != null, location: state.matchedLocation);
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.today, builder: (_, __) => const TodayPage())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.path, builder: (_, __) => const PathPage())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.practice, builder: (_, __) => const PracticePage())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.progress, builder: (_, __) => const ProgressPage())]),
        ],
      ),
      GoRoute(
        path: Routes.session,
        parentNavigatorKey: rootKey,
        // Sin plan (p. ej. al abrir un enlace), se vuelve a Hoy.
        redirect: (_, state) => state.extra is SessionPlan ? null : Routes.today,
        pageBuilder: (_, state) => MaterialPage(fullscreenDialog: true, child: SessionPage(plan: state.extra! as SessionPlan)),
      ),
    ],
  );
});
