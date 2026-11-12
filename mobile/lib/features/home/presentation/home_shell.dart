import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/app_update.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/tr.dart';

/// Las 4 pestañas con la barra de abajo. Cada pestaña guarda su posición al cambiar.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    // ¿Hay versión nueva en Play? Una vez al entrar.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(appUpdateProvider.notifier).check());
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final offline = ref.watch(offlineProvider);
    final update = ref.watch(appUpdateProvider);
    return Scaffold(
      backgroundColor: W.callBg,
      body: SafeArea(
        child: Column(children: [
          if (offline)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF7EC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(tr('Sin conexión: ves lo guardado. Las fichas que hagas se suben al volver.'), style: TextStyle(color: Color(0xFF6B4A1E), fontSize: 13.5)),
            ),
          if (update != UpdateStage.none) _UpdateBanner(stage: update),
          Expanded(child: shell),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: tr('Hoy')),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map), label: tr('Camino')),
          NavigationDestination(icon: const Icon(Icons.mic_none), selectedIcon: const Icon(Icons.mic), label: tr('Practicar')),
          NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart), label: tr('Progreso')),
        ],
      ),
    );
  }
}

/// El aviso de versión nueva: "Actualizar" → se descarga → "Reiniciar".
class _UpdateBanner extends ConsumerWidget {
  const _UpdateBanner({required this.stage});
  final UpdateStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(appUpdateProvider.notifier);
    final (text, action, onTap) = switch (stage) {
      UpdateStage.available => (tr('Hay una versión nueva de W2W.'), tr('Actualizar'), c.download),
      UpdateStage.downloading => (tr('Descargando la versión nueva…'), null, null),
      UpdateStage.ready => (tr('La versión nueva está lista.'), tr('Reiniciar'), c.install),
      UpdateStage.none => ('', null, null),
    };
    return Container(
      width: double.infinity,
      color: W.navy,
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      child: Row(children: [
        const Icon(Icons.system_update, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
        if (stage == UpdateStage.downloading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          ),
        if (action != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: W.yellow),
            onPressed: onTap,
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        if (stage == UpdateStage.available)
          IconButton(
            tooltip: tr('Ahora no'),
            onPressed: c.dismiss,
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
          ),
      ]),
    );
  }
}
