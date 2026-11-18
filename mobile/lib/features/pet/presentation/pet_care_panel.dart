import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../data/pet.dart';
import 'pet_actions.dart';
import 'pet_figure.dart';
import 'pet_texts.dart';

/// Brainy con lo que dice ahora (un globo con inglés muy fácil).
class PetWithBubble extends ConsumerWidget {
  const PetWithBubble({super.key, required this.pet, this.size = 230});
  final PetState pet;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thanks = ref.watch(petThanksProvider);
    final care = pet.care;
    final text = thanks != null ? petThanks(thanks) : (care == null ? null : petBubble(care));
    return SizedBox(
      width: size * 1.25,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        PetFigure(pet: pet, size: size),
        if (text != null)
          Positioned(
            top: size * 0.04,
            right: 0,
            child: Container(
              key: const ValueKey('pet-bubble'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomRight: Radius.circular(14), bottomLeft: Radius.circular(3)),
                border: Border.all(color: W.line),
              ),
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
      ]),
    );
  }
}

/// Los cuidados de Brainy: cómo está, sus cuatro barras de corazones y los botones.
/// Cada botón abre un ejercicio de W2W de siempre; hacerlo es lo que la cuida.
class PetCarePanel extends ConsumerStatefulWidget {
  const PetCarePanel({super.key, required this.care, this.onAction});
  final PetCare care;

  /// Para probar la pantalla sin navegar. Por defecto, [runPetCare].
  final Future<void> Function(PetAction action)? onAction;

  @override
  ConsumerState<PetCarePanel> createState() => _PetCarePanelState();
}

class _PetCarePanelState extends ConsumerState<PetCarePanel> {
  PetAction? _busy;

  Future<void> _run(PetAction action) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    try {
      await (widget.onAction?.call(action) ?? runPetCare(context, ref, action));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final care = widget.care;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(petMoodText(care), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(tr('Cuidarla es estudiar: cada botón abre un ejercicio.'), style: const TextStyle(color: W.muted, fontSize: 13)),
        const SizedBox(height: 6),
        for (final n in PetNeed.values)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(child: Text(petNeedName(n))),
              PetHearts(key: ValueKey('hearts-${n.name}'), count: care.of(n), max: care.max, color: petNeedColors[n]!, label: petNeedName(n)),
            ]),
          ),
        const SizedBox(height: 14),
        Row(children: [
          for (final a in PetAction.values) ...[
            if (a != PetAction.values.first) const SizedBox(width: 8),
            Expanded(child: _CareButton(action: a, busy: _busy == a, highlight: _wants(care, a), onTap: _busy == null ? () => _run(a) : null)),
          ],
        ]),
      ]),
    );
  }

  /// El botón que más falta hace ahora se marca (sin obligar a nada).
  static bool _wants(PetCare c, PetAction a) => switch (a) {
        PetAction.feed => c.mood == 'hungry',
        PetAction.play => c.mood == 'bored',
        PetAction.clean => c.mood == 'messy',
        PetAction.medicine => c.sick,
      };
}

class _CareButton extends StatelessWidget {
  const _CareButton({required this.action, required this.busy, required this.highlight, this.onTap});
  final PetAction action;
  final bool busy, highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${petActionName(action)}: ${petActionHint(action)}',
      child: Material(
        color: highlight ? const Color(0xFFFFF6C7) : const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('pet-${action.name}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: ExcludeSemantics(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Opacity(opacity: busy ? 0.4 : 1, child: Text(petActionEmoji(action), style: const TextStyle(fontSize: 24))),
                const SizedBox(height: 4),
                FittedBox(child: Text(petActionName(action), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                FittedBox(child: Text(petActionHint(action), style: const TextStyle(color: W.muted, fontSize: 11))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una barra de corazones dibujada con código (sin iconos): [count] llenos de [max].
class PetHearts extends StatelessWidget {
  const PetHearts({super.key, required this.count, required this.max, required this.color, this.label = '', this.size = 18});
  final int count, max;
  final Color color;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label: ${tr('{0} de {1}', [count, max])}',
        child: CustomPaint(size: Size(size * max + 4.0 * (max - 1), size), painter: _HeartsPainter(count, max, color)),
      );
}

class _HeartsPainter extends CustomPainter {
  _HeartsPainter(this.count, this.max, this.color);
  final int count, max;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height;
    for (var i = 0; i < max; i++) {
      final o = Offset(i * (s + 4), 0);
      // Un corazón: dos arcos arriba y una punta abajo.
      final heart = Path()
        ..moveTo(o.dx + s * 0.5, o.dy + s * 0.92)
        ..cubicTo(o.dx - s * 0.20, o.dy + s * 0.45, o.dx + s * 0.10, o.dy - s * 0.10, o.dx + s * 0.5, o.dy + s * 0.28)
        ..cubicTo(o.dx + s * 0.90, o.dy - s * 0.10, o.dx + s * 1.20, o.dy + s * 0.45, o.dx + s * 0.5, o.dy + s * 0.92)
        ..close();
      canvas.drawPath(heart, Paint()..color = i < count ? color : W.line);
    }
  }

  @override
  bool shouldRepaint(covariant _HeartsPainter old) => old.count != count || old.max != max || old.color != color;
}
