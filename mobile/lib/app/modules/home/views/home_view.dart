import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../path/views/path_view.dart';
import '../../practice/views/practice_view.dart';
import '../../progress/views/progress_view.dart';
import '../../today/views/today_view.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  static const _pages = [TodayView(), PathView(), PracticeView(), ProgressView()];

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
          body: SafeArea(child: _pages[controller.tab.value]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: controller.tab.value,
            onDestinationSelected: controller.go,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Hoy'),
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Camino'),
              NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'Practicar'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Progreso'),
            ],
          ),
        ));
  }
}
