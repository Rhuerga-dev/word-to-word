import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Franja de abajo con la respuesta y "Continuar".
class FeedbackBar extends StatelessWidget {
  const FeedbackBar({super.key, required this.ok, required this.title, this.detail, required this.onNext});
  final bool ok;
  final String title;
  final String? detail;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final c = ok ? W.good : W.warn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), border: Border(top: BorderSide(color: c.withValues(alpha: .5), width: 2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: W.display(22, color: c)),
        if (detail != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(detail!)),
        const SizedBox(height: 12),
        FilledButton(onPressed: onNext, child: const Text('Continuar')),
      ]),
    );
  }
}
