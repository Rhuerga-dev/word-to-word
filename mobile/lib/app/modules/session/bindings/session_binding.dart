import 'package:get/get.dart';

import '../controllers/session_controller.dart';
import '../models/session_plan.dart';

/// La sesión recibe su plan en Get.arguments.
class SessionBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(SessionController(Get.arguments as SessionPlan));
  }
}
