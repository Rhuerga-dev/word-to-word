import 'package:get/get.dart';

import '../../path/controllers/path_controller.dart';
import '../../practice/controllers/practice_controller.dart';
import '../../progress/controllers/progress_controller.dart';
import '../../today/controllers/today_controller.dart';
import '../controllers/home_controller.dart';

/// Inicio con las 4 secciones: cada una tiene su controlador.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeController());
    Get.put(TodayController());
    Get.lazyPut(() => PathController());
    Get.lazyPut(() => PracticeController());
    Get.lazyPut(() => ProgressController());
  }
}
