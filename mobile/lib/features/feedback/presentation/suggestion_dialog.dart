import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../data/feedback_repository.dart';

/// «Enviar sugerencia»: elegir qué es (idea, fallo u otra cosa), escribir y enviar.
/// [screen] dice desde qué pantalla se abrió. Sin iconos nuevos (parche de Shorebird).
class SuggestionDialog extends ConsumerStatefulWidget {
  const SuggestionDialog({super.key, required this.screen});
  final String screen;

  static const minLength = 5, maxLength = 2000;

  @override
  ConsumerState<SuggestionDialog> createState() => _SuggestionDialogState();
}

class _SuggestionDialogState extends ConsumerState<SuggestionDialog> {
  static const _labels = {
    SuggestionType.idea: 'Una idea',
    SuggestionType.bug: 'Algo no funciona',
    SuggestionType.other: 'Otra cosa',
  };

  final _text = TextEditingController();
  SuggestionType _type = SuggestionType.idea;
  bool _busy = false, _sent = false;
  String _msg = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _text.text.trim();
    if (message.length < SuggestionDialog.minLength) {
      setState(() => _msg = tr('Escribe un poco más.'));
      return;
    }
    final repo = ref.read(feedbackRepositoryProvider);
    setState(() {
      _busy = true;
      _msg = '';
    });
    try {
      await repo.send(type: _type, message: message, screen: widget.screen);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AlertDialog(
        title: Text(tr('¡Gracias!')),
        content: Text(tr('Recibimos tu sugerencia. Leo todas, aunque no siempre pueda responder.')),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cerrar')))],
      );
    }
    return AlertDialog(
      title: Text('💡 ${tr('Enviar sugerencia')}'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<SuggestionType>(
            key: const ValueKey('suggestion-type'),
            isExpanded: true,
            initialValue: _type,
            decoration: InputDecoration(labelText: tr('¿Qué es?')),
            items: [for (final t in SuggestionType.values) DropdownMenuItem(value: t, child: Text(tr(_labels[t]!)))],
            onChanged: _busy ? null : (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('suggestion-text'),
            controller: _text,
            enabled: !_busy,
            minLines: 4,
            maxLines: 8,
            maxLength: SuggestionDialog.maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: tr('Cuéntame tu idea o lo que no funciona…'), alignLabelWithHint: true),
          ),
          if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg, style: const TextStyle(color: W.bad))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(tr('Cancelar'))),
        FilledButton(
          key: const ValueKey('suggestion-send'),
          onPressed: _busy ? null : _send,
          child: Text(_busy ? tr('Enviando…') : tr('Enviar')),
        ),
      ],
    );
  }
}
