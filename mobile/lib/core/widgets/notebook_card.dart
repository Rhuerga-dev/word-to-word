import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ficha de estudio estilo "Libreta": franja rosa arriba y renglones azules.
class NotebookCard extends StatelessWidget {
  const NotebookCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0xFFC9D4E3), offset: Offset(0, 1)), BoxShadow(color: Color(0x1416212E), blurRadius: 24, offset: Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 14, color: W.cardTop),
        CustomPaint(
          painter: _Rules(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
      ]),
    );
  }
}

class _Rules extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = W.rule
      ..strokeWidth = 1;
    for (var y = 72.0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _Rules old) => false;
}

/// Palabra resaltada con marcador amarillo.
class Highlight extends StatelessWidget {
  const Highlight(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        color: W.yellow,
        child: Text(text, style: style),
      );
}
