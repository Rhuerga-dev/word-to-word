import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/core/theme/app_theme.dart';
import 'app/data/providers/api_client.dart';
import 'app/data/services/audio_service.dart';
import 'app/data/services/auth_service.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = Get.put(Api(), permanent: true);
  Get.put(AppAudio(api), permanent: true);
  Get.put(AuthService(api), permanent: true);
  runApp(GetMaterialApp(
    title: 'Word to Word',
    debugShowCheckedModeBanner: false,
    theme: W.theme(),
    initialRoute: Routes.splash,
    getPages: AppPages.pages,
  ));
}
