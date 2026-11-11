import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../data/services/auth_service.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  final auth = Get.find<AuthService>();
  final email = TextEditingController();
  final password = TextEditingController();
  final busy = false.obs;
  final error = ''.obs;

  Future<void> login() => _run(() => auth.login(email.text.trim(), password.text));
  Future<void> demo() => _run(auth.demo);

  Future<void> _run(Future<void> Function() fn) async {
    busy.value = true;
    error.value = '';
    try {
      await fn();
      Get.offAllNamed(Routes.home);
    } catch (e) {
      error.value = e.toString();
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    super.onClose();
  }
}
