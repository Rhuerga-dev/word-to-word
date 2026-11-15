import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';
import '../../../core/l10n/tr.dart';

/// Pasa a mayúsculas lo que se escribe (el código de invitación), sin mover el cursor.
final _upperCase = TextInputFormatter.withFunction((old, v) => v.copyWith(text: v.text.toUpperCase()));

/// Entrar con correo, crear cuenta (con código de invitación) o probar la demo. Al entrar, el router lleva solo a Hoy.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _invite = TextEditingController();
  bool _busy = false;
  String _error = '';

  /// Crear cuenta en vez de entrar.
  bool _register = false;

  /// Si el registro pide código (por defecto sí, hasta que /config diga otra cosa).
  bool _inviteRequired = true;
  bool _configAsked = false;

  /// Error del servidor para el código (errors.invite), debajo de su campo.
  String? _inviteError;

  Future<bool> _run(Future<void> Function(AuthController c) fn) async {
    setState(() {
      _busy = true;
      _error = '';
      _inviteError = null;
    });
    try {
      await fn(ref.read(authControllerProvider.notifier));
      return true;
    } on ApiException catch (e) {
      final invite = e.errors['invite'];
      if (mounted) {
        setState(() {
          if (invite != null && _register) {
            _inviteError = invite;
            _inviteRequired = true;
            // Lo demás (si hay otro error) va arriba del botón; el del código no se repite.
            _error = e.errors.entries.where((x) => x.key != 'invite').map((x) => x.value).firstOrNull ?? '';
          } else {
            _error = e.message;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  /// Al entrar bien, el teléfono ofrece guardar la contraseña (Google / Samsung Pass) para la próxima vez.
  Future<void> _login() async {
    final ok = await _run((c) => c.login(_email.text.trim(), _password.text));
    TextInput.finishAutofillContext(shouldSave: ok);
  }

  Future<void> _signUp() async {
    final invite = _invite.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final ok = await _run((c) => c.register(
          name: _name.text.trim().isEmpty ? 'Estudiante' : _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          invite: invite.isNotEmpty || _inviteRequired ? invite : null,
        ));
    TextInput.finishAutofillContext(shouldSave: ok);
  }

  void _toggleMode() {
    setState(() {
      _register = !_register;
      _error = '';
      _inviteError = null;
    });
    if (_register && !_configAsked) {
      _configAsked = true;
      ref.read(authRepositoryProvider).inviteRequired().then((v) {
        if (mounted) setState(() => _inviteRequired = v);
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _invite.dispose();
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
            Text('W2W', style: W.display(36)),
            const SizedBox(height: 8),
            Text(tr('Aprende a hablar inglés con una sesión guiada cada día.'), style: TextStyle(color: W.muted, fontSize: 16)),
            const SizedBox(height: 32),
            AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_register) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(labelText: tr('Nombre'), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              decoration: InputDecoration(labelText: tr('Correo'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(labelText: tr('Contraseña'), border: OutlineInputBorder()),
              onSubmitted: _register ? null : (_) => _login(),
            ),
            if (_register && (_inviteRequired || _inviteError != null)) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('invite'),
                controller: _invite,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 40,
                inputFormatters: [_upperCase],
                decoration: InputDecoration(
                  labelText: tr('Código de invitación'),
                  hintText: 'W2W-XXXX-XXXX',
                  helperText: tr('W2W es solo por invitación. Pide un código a quien te invitó.'),
                  helperMaxLines: 3,
                  errorText: _inviteError,
                  errorMaxLines: 3,
                  counterText: '',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _signUp(),
              ),
            ],
              ]),
            ),
            if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error, style: const TextStyle(color: W.bad))),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : (_register ? _signUp : _login),
              child: Text(_register ? tr('Crear cuenta') : tr('Entrar')),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _busy ? null : () => _run((c) => c.demo()), child: Text(tr('Probar la demo, sin registrarte'))),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _busy ? null : _toggleMode,
              child: Text(
                _register ? tr('Ya tengo cuenta: entrar') : tr('¿No tienes cuenta? Crea una con tu código de invitación'),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
