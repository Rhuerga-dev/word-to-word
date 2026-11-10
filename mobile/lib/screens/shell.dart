import 'package:flutter/material.dart';

import 'path_screen.dart';
import 'practice_screen.dart';
import 'progress_screen.dart';
import 'today_screen.dart';

/// Las 4 secciones con la barra de abajo: Hoy · Camino · Practicar · Progreso.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _keys = List.generate(4, (_) => UniqueKey());

  void go(int i) => setState(() {
        _tab = i;
        _keys[i] = UniqueKey(); // al volver a una sección, se recarga
      });

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(key: _keys[0], onGo: go),
      PathScreen(key: _keys[1]),
      PracticeScreen(key: _keys[2]),
      ProgressScreen(key: _keys[3]),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: go,
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
