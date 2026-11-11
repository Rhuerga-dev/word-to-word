import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hands_free.dart';
import '../theme/app_theme.dart';

/// Página de un ejercicio: contenido con scroll y la barra de abajo.
/// Con manos libres, la barra de abajo se oculta: la sesión muestra la del modo voz.
class StepPage extends ConsumerWidget {
  const StepPage({super.key, required this.children, this.bottom, this.padding = const EdgeInsets.fromLTRB(22, 14, 22, 22)});
  final List<Widget> children;
  final Widget? bottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handsFree = ref.watch(handsFreeProvider.select((s) => s.on));
    return Column(children: [
      Expanded(child: ListView(padding: padding, children: children)),
      if (bottom != null && !handsFree) bottom!,
    ]);
  }
}

Widget stepKind(String t, {Color color = W.muted}) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
    );

Widget bottomPad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: child);
