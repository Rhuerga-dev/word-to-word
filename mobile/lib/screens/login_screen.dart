import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String _error = '';

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<Auth>();
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
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              onSubmitted: (_) => _run(() => auth.login(_email.text.trim(), _password.text)),
            ),
            if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error, style: const TextStyle(color: W.bad))),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _run(() => auth.login(_email.text.trim(), _password.text)),
              child: const Text('Entrar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(auth.demo),
              child: const Text('Probar la demo, sin registrarte'),
            ),
            const SizedBox(height: 24),
            const Text('¿No tienes cuenta? Créala en w2w.huergalabs.dev', textAlign: TextAlign.center, style: TextStyle(color: W.muted)),
          ],
        ),
      ),
    );
  }
}
