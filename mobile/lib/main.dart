import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'api.dart';
import 'audio.dart';
import 'auth.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = Get.put(Api(), permanent: true);
  Get.put(AppAudio(api), permanent: true);
  Get.put(Auth(api), permanent: true);
  runApp(const WordToWordApp());
}

class WordToWordApp extends StatelessWidget {
  const WordToWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<Auth>();
    return GetMaterialApp(
      title: 'Word to Word',
      debugShowCheckedModeBanner: false,
      theme: W.theme(),
      home: Obx(() {
        if (auth.loading.value) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return auth.loggedIn ? const Shell() : const LoginScreen();
      }),
    );
  }
}
