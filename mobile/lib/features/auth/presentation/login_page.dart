import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import '../../../core/l10n/tr.dart';

/// Entrar con correo o probar la demo. Al entrar, el router lleva solo a Hoy.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String _error = '';

  Future<void> _run(Future<void> Function(AuthController c) fn) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await fn(ref.read(authControllerProvider.notifier));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _login() => _run((c) => c.login(_email.text.trim(), _password.text));

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

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
            Text(tr('Aprende a hablar inglés con una sesión guiada cada día.'), style: TextStyle(color: W.muted, fontSize: 16)),
            const SizedBox(height: 32),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: tr('Correo'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: tr('Contraseña'), border: OutlineInputBorder()),
              onSubmitted: (_) => _login(),
            ),
            if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error, style: const TextStyle(color: W.bad))),
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _login, child: Text(tr('Entrar'))),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _busy ? null : () => _run((c) => c.demo()), child: Text(tr('Probar la demo, sin registrarte'))),
            const SizedBox(height: 24),
            Text(tr('¿No tienes cuenta? Créala en w2w.huergalabs.dev'), textAlign: TextAlign.center, style: TextStyle(color: W.muted)),
          ],
        ),
      ),
    );
  }
}
