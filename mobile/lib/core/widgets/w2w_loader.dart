import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// El "cargando" de W2W: barras de voz que suben y bajan (la app es para hablar).
/// Sustituye a la rueda genérica de Material. Si el teléfono pide menos movimiento, quedan quietas.
class W2WLoader extends StatefulWidget {
  const W2WLoader({super.key, this.size = 44, this.color, this.label});

  /// Para dentro de botones y avisos (sin texto).
  const W2WLoader.small({super.key, this.color})
      : size = 18,
        label = null;

  /// Alto de las barras.
  final double size;

  /// Color de las barras (por defecto, el azul de W2W).
  final Color? color;

  /// Texto debajo, por ejemplo «Cargando…» (solo en el tamaño grande).
  final String? label;

  @override
  State<W2WLoader> createState() => _W2WLoaderState();
}

class _W2WLoaderState extends State<W2WLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? W.accent;
    final small = widget.size < 28;
    final bars = small ? 3 : 5;
    final barW = widget.size * (small ? 0.2 : 0.14);
    final gap = barW * (small ? 0.7 : 0.6);
    final loader = Semantics(
      label: widget.label ?? 'Cargando',
      child: SizedBox(
        key: const ValueKey('w2w-loader'),
        height: widget.size,
        width: bars * barW + (bars - 1) * gap,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < bars; i++)
                Container(
                  width: barW,
                  height: widget.size * _level(i, bars),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(barW)),
                ),
            ],
          ),
        ),
      ),
    );
    if (widget.label == null || small) return loader;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      loader,
      const SizedBox(height: 14),
      // El lector de pantalla ya lo dice una vez (en las barras): el texto no se repite.
      ExcludeSemantics(child: Text(widget.label!, style: TextStyle(color: color == W.accent ? W.muted : color, fontSize: 15))),
    ]);
  }

  /// Alto de cada barra: las del centro más altas y cada una con su ritmo, como una voz.
  double _level(int i, int bars) {
    const base5 = [0.55, 0.85, 1.0, 0.8, 0.6], base3 = [0.7, 1.0, 0.75];
    const shift5 = [0.0, 0.42, 0.18, 0.66, 0.3], shift3 = [0.0, 0.4, 0.75];
    final base = bars == 3 ? base3[i] : base5[i];
    if (!_c.isAnimating) return base * 0.75;
    final phase = (_c.value + (bars == 3 ? shift3[i] : shift5[i])) * 2 * math.pi;
    return base * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(phase)));
  }
}

/// Pantalla completa de espera (por ejemplo, al abrir la app mientras se recupera la sesión).
class W2WLoadingScreen extends StatelessWidget {
  const W2WLoadingScreen({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: W.callBg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('W2W', style: W.display(34, color: W.navy)),
            const SizedBox(height: 22),
            W2WLoader(label: label),
          ]),
        ),
      );
}
