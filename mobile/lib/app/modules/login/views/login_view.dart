import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            Text('Word to Word', style: W.display(36)),
            const SizedBox(height: 8),
            const Text('Aprende a hablar inglés con una sesión guiada cada día.', style: TextStyle(color: W.muted, fontSize: 16)),
            const SizedBox(height: 32),
            TextField(
              controller: controller.email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              onSubmitted: (_) => controller.login(),
            ),
            Obx(() => controller.error.value.isEmpty
                ? const SizedBox.shrink()
                : Padding(padding: const EdgeInsets.only(top: 12), child: Text(controller.error.value, style: const TextStyle(color: W.bad)))),
            const SizedBox(height: 20),
            Obx(() => FilledButton(onPressed: controller.busy.value ? null : controller.login, child: const Text('Entrar'))),
            const SizedBox(height: 12),
            Obx(() => OutlinedButton(onPressed: controller.busy.value ? null : controller.demo, child: const Text('Probar la demo, sin registrarte'))),
            const SizedBox(height: 24),
            const Text('¿No tienes cuenta? Créala en w2w.huergalabs.dev', textAlign: TextAlign.center, style: TextStyle(color: W.muted)),
          ],
        ),
      ),
    );
  }
}
