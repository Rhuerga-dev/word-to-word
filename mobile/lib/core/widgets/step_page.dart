import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StepPage extends StatelessWidget {
  const StepPage({super.key, required this.children, this.bottom});
  final List<Widget> children;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(22, 14, 22, 22), children: children)),
        if (bottom != null) bottom!,
      ]);
}

Widget stepKind(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(t.toUpperCase(), style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.w700, color: W.muted, fontSize: 13)),
    );

Widget bottomPad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: child);
