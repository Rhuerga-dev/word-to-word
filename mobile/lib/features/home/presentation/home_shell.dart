import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/offline_cache.dart';
import '../../../core/theme/app_theme.dart';

/// Las 4 pestañas con la barra de abajo. Cada pestaña guarda su posición al cambiar.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider);
    return Scaffold(
      backgroundColor: W.callBg,
      body: SafeArea(
        child: Column(children: [
          if (offline)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF7EC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text('Sin conexión: ves lo guardado. Las fichas que hagas se suben al volver.', style: TextStyle(color: Color(0xFF6B4A1E), fontSize: 13.5)),
            ),
          Expanded(child: shell),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Hoy'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Camino'),
          NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'Practicar'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Progreso'),
        ],
      ),
    );
  }
}
