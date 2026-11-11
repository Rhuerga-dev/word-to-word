import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/spanish/data/spanish_repository.dart';
import '../l10n/tr.dart';
import '../theme/app_theme.dart';

/// El español "a pedido" de la escalera: en el escalón 1 se ve tal cual, en 2–3 detrás de un botón que
/// cuenta un uso (con límite diario en el 3) y en el 4 no aparece.
class SpanishPeek extends ConsumerStatefulWidget {
  const SpanishPeek({super.key, required this.child, this.kind = 'translation', this.color});
  final Widget child;
  final String kind;
  final Color? color;

  @override
  ConsumerState<SpanishPeek> createState() => _SpanishPeekState();
}

class _SpanishPeekState extends ConsumerState<SpanishPeek> {
  bool _open = false, _busy = false;
  String _msg = '';

  Future<void> _ask() async {
    setState(() => _busy = true);
    try {
      await ref.read(spanishRepositoryProvider).use(widget.kind);
      _open = true;
      _msg = '';
      refreshSpanish(ref);
    } catch (e) {
      _msg = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final sp = ref.watch(spanishProvider);
    if (sp.step <= 1 || _open) return widget.child;
    if (sp.noSpanish) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      TextButton.icon(
        style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: widget.color ?? W.accent, visualDensity: VisualDensity.compact),
        onPressed: _busy ? null : _ask,
        icon: const Icon(Icons.translate, size: 18),
        label: Text(sp.left != null ? '${tr('Ver en español')} (${sp.left})' : tr('Ver en español')),
      ),
      if (_msg.isNotEmpty) Text(_msg, style: TextStyle(color: widget.color ?? W.warn, fontSize: 13)),
    ]);
  }
}

/// Botón "Traducir" para un comentario del coach (escalones 2–3). Cuenta un uso.
class TranslateButton extends ConsumerStatefulWidget {
  const TranslateButton({super.key, required this.text, this.color});
  final String text;
  final Color? color;

  @override
  ConsumerState<TranslateButton> createState() => _TranslateButtonState();
}

class _TranslateButtonState extends ConsumerState<TranslateButton> {
  String? _es;
  String _msg = '';
  bool _busy = false;

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      _es = await ref.read(spanishRepositoryProvider).translate(widget.text);
      _msg = '';
      refreshSpanish(ref);
    } catch (e) {
      _msg = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final sp = ref.watch(spanishProvider);
    if (sp.step <= 1 || sp.noSpanish) return const SizedBox.shrink();
    final c = widget.color ?? W.muted;
    if (_es != null) return Padding(padding: const EdgeInsets.only(top: 4), child: Text(_es!, style: TextStyle(color: c, fontStyle: FontStyle.italic)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      TextButton.icon(
        style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: c, visualDensity: VisualDensity.compact),
        onPressed: _busy ? null : _go,
        icon: const Icon(Icons.translate, size: 18),
        label: Text(tr('Traducir')),
      ),
      if (_msg.isNotEmpty) Text(_msg, style: TextStyle(color: c, fontSize: 13)),
    ]);
  }
}

/// Trae el contador de español actualizado (sin esperar).
void refreshSpanish(WidgetRef ref) {
  ref.read(spanishRepositoryProvider).fetch().then(ref.read(authControllerProvider.notifier).setSpanish).catchError((_) {});
}
