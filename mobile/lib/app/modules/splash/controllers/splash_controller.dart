import 'package:get/get.dart';

import '../../../data/services/auth_service.dart';
import '../../../routes/app_routes.dart';

/// Recupera la sesión guardada y decide a dónde ir.
class SplashController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    Get.find<AuthService>().restore().then((inside) => Get.offAllNamed(inside ? Routes.home : Routes.login));
  }
}
