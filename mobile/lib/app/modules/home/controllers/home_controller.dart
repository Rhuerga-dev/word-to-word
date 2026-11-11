import 'package:get/get.dart';

import '../../path/controllers/path_controller.dart';
import '../../practice/controllers/practice_controller.dart';
import '../../progress/controllers/progress_controller.dart';
import '../../today/controllers/today_controller.dart';

/// Pestaña elegida en la barra de abajo: Hoy · Camino · Practicar · Progreso.
class HomeController extends GetxController {
  final tab = 0.obs;

  /// Cambia de pestaña; al volver a una sección, sus datos se recargan.
  void go(int i) {
    final again = tab.value != i;
    tab.value = i;
    if (!again) return;
    switch (i) {
      case 0:
        Get.find<TodayController>().load();
      case 1:
        if (Get.isRegistered<PathController>()) Get.find<PathController>().load();
      case 2:
        if (Get.isRegistered<PracticeController>()) Get.find<PracticeController>().load();
      case 3:
        if (Get.isRegistered<ProgressController>()) Get.find<ProgressController>().load();
    }
  }
}
