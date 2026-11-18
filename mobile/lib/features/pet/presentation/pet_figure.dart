import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../data/pet.dart';
import 'pet_brain.dart';
import 'pet_texts.dart';

/// Brainy: una criatura redonda con la cabeza transparente; dentro se ve su cerebro, que se
/// enciende con lo que aprendes. Diseño propio, dibujado con código (sin imágenes).
/// Crece con cada etapa: abre los ojos, le sale un brote, brazos, voz y, al final, brilla.
/// Respira, parpadea y sus neuronas laten; con «Reducir movimiento» se queda quieta.
class PetFigure extends StatefulWidget {
  const PetFigure({super.key, required this.pet, this.size = 220, this.fit = false});
  final PetState pet;
  final double size;

  /// true = siempre al tamaño máximo que cabe (para sitios pequeños, como la tarjeta de Hoy).
  /// false = su tamaño depende de la etapa: se la ve crecer.
  final bool fit;

  @override
  State<PetFigure> createState() => _PetFigureState();
}

class _PetFigureState extends State<PetFigure> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pet;
    return Semantics(
      image: true,
      label: tr('{0}, tu mascota. Etapa: {1}', [p.name, petStageName(p)]),
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(animation: _clock, builder: (_, __) => CustomPaint(painter: PetPainter(p, _clock.isAnimating ? _clock.value : null, fit: widget.fit))),
        ),
      ),
    );
  }
}

/// Dibuja la mascota. [time] va de 0 a 1 en bucle; null = quieta.
class PetPainter extends CustomPainter {
  PetPainter(this.pet, this.time, {this.fit = false});
  final PetState pet;
  final double? time;
  final bool fit;

  /// Lo más grande que cabe con todo lo que le sale en la última etapa (brote, voz y brillo).
  static const maxGrow = 0.74;

  static const _body = Color(0xFF0F2A86), _bodyDark = Color(0xFF0A1B5C), _dome = Color(0xFF0A1210);
  static const _off = Color(0xFF3A4660);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time ?? 0.0, moving = time != null;
    final stage = pet.stage;
    // Tamaño: de pequeña a grande con las etapas (en la última ocupa todo lo que cabe).
    final grow = fit ? maxGrow : maxGrow - 0.065 * (4 - math.min(stage, 4));
    final breath = moving ? 1 + 0.012 * math.sin(t * 2 * math.pi * 2) : 1.0;
    final u = size.shortestSide / 2 * grow * breath; // unidad: medio alto de la criatura
    final c = Offset(size.width / 2, size.height / 2 + size.shortestSide * 0.05);

    if (stage >= 4) _glow(canvas, c, u, t, moving);

    // Sombra en el suelo.
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, u * 0.93), width: u * 1.25, height: u * 0.16), Paint()..color = const Color(0x22000000));

    // Pies y brazos (desde «Aprendiz»).
    final limb = Paint()..color = _bodyDark;
    if (stage >= 2) {
      canvas.drawOval(Rect.fromCenter(center: c + Offset(-u * 0.30, u * 0.88), width: u * 0.34, height: u * 0.16), limb);
      canvas.drawOval(Rect.fromCenter(center: c + Offset(u * 0.30, u * 0.88), width: u * 0.34, height: u * 0.16), limb);
      final wave = moving ? 0.10 * math.sin(t * 2 * math.pi * 3) : 0.0;
      _arm(canvas, c + Offset(-u * 0.76, u * 0.30), u, -0.5 + wave, limb);
      _arm(canvas, c + Offset(u * 0.76, u * 0.30), u, 0.5 - wave, limb);
    }

    // Brote en la cabeza (desde «Brote»): un tallo con dos hojas.
    if (stage >= 1) _sprout(canvas, c + Offset(0, -u * 0.86), u, moving ? 0.08 * math.sin(t * 2 * math.pi * 2) : 0.0);

    // Cuerpo: un huevo redondeado.
    final body = Rect.fromCenter(center: c, width: u * 1.62, height: u * 1.82);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(u * 0.78)),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_body, _bodyDark]).createShader(body),
    );

    // Cabeza transparente con el cerebro dentro.
    final dome = Rect.fromCenter(center: c + Offset(0, -u * 0.26), width: u * 1.36, height: u * 1.02);
    canvas.drawRRect(RRect.fromRectAndRadius(dome, Radius.circular(u * 0.50)), Paint()..color = _dome);
    _brain(canvas, dome.center, u * 0.60, t, moving);
    canvas.drawRRect(
      RRect.fromRectAndRadius(dome, Radius.circular(u * 0.50)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.02
        ..color = const Color(0x55C8D6FF),
    );

    _face(canvas, c + Offset(0, u * 0.50), u, t, moving, stage);

    // Voz (desde «Voz»): ondas junto a la boca.
    if (stage >= 3) _voice(canvas, c + Offset(u * 0.92, u * 0.42), u, t, moving);
  }

  void _brain(Canvas canvas, Offset c, double s, double t, bool moving) {
    final brain = PetBrain.instance;
    Offset at(Neuron n) => c + Offset(n.x * s, n.y * s * 0.94);
    final line = Paint()
      ..strokeWidth = math.max(0.6, s * 0.012)
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in brain.links) {
      final na = brain.neurons[a], nb = brain.neurons[b];
      final on = na.lit(pet.level(na.region)) && nb.lit(pet.level(nb.region));
      line.color = on ? (na.region == nb.region ? petColors[na.region]! : petColors[PetRegion.links]!).withValues(alpha: 0.45) : _off.withValues(alpha: 0.30);
      canvas.drawLine(at(na), at(nb), line);
    }
    final dot = Paint();
    for (final n in brain.neurons) {
      final p = at(n);
      if (!n.lit(pet.level(n.region))) {
        canvas.drawCircle(p, s * 0.022, dot..color = _off);
        continue;
      }
      final color = petColors[n.region]!;
      final beat = moving ? 0.5 + 0.5 * math.sin((t * 3 + n.phase) * 2 * math.pi) : 0.6;
      canvas.drawCircle(p, s * (0.050 + 0.022 * beat), dot..color = color.withValues(alpha: 0.22));
      canvas.drawCircle(p, s * 0.030, dot..color = color);
      canvas.drawCircle(p, s * 0.012, dot..color = Colors.white.withValues(alpha: 0.85));
    }
  }

  void _face(Canvas canvas, Offset c, double u, double t, bool moving, int stage) {
    final white = Paint()..color = Colors.white;
    final ink = Paint()..color = const Color(0xFF16212E);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.035
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    final eyeDx = u * 0.26;

    // Recién nacida: ojos cerrados y contentos (dos arcos). Después, abiertos y con parpadeo.
    final blink = moving && (t * 6) % 3 > 2.9;
    for (final side in [-1, 1]) {
      final e = c + Offset(eyeDx * side, 0);
      if (stage == 0 || blink) {
        canvas.drawArc(Rect.fromCenter(center: e + Offset(0, u * 0.03), width: u * 0.20, height: u * 0.16), math.pi, math.pi, false, stroke);
      } else {
        canvas.drawCircle(e, u * 0.105, white);
        canvas.drawCircle(e + Offset(u * 0.015 * side, u * 0.01), u * 0.055, ink);
        canvas.drawCircle(e + Offset(u * 0.035, -u * 0.035), u * 0.020, white);
      }
    }
    // Mejillas.
    final cheek = Paint()..color = const Color(0x55F07A9A);
    canvas.drawCircle(c + Offset(-u * 0.44, u * 0.12), u * 0.07, cheek);
    canvas.drawCircle(c + Offset(u * 0.44, u * 0.12), u * 0.07, cheek);
    // Boca: siempre sonríe. Desde «Voz», abierta (está hablando).
    final mouth = Rect.fromCenter(center: c + Offset(0, u * 0.13), width: u * 0.24, height: u * 0.18);
    if (stage >= 3) {
      canvas.drawArc(mouth, 0, math.pi, true, white);
    } else {
      canvas.drawArc(mouth, 0.15, math.pi - 0.3, false, stroke);
    }
  }

  void _arm(Canvas canvas, Offset c, double u, double turn, Paint paint) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turn);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: u * 0.16, height: u * 0.40), Radius.circular(u * 0.08)), paint);
    canvas.restore();
  }

  void _sprout(Canvas canvas, Offset base, double u, double sway) {
    const green = Color(0xFF4AC487);
    final top = base + Offset(u * sway, -u * 0.20);
    canvas.drawLine(
      base + Offset(0, u * 0.05),
      top,
      Paint()
        ..color = green
        ..strokeWidth = u * 0.035
        ..strokeCap = StrokeCap.round,
    );
    for (final side in [-1, 1]) {
      canvas.save();
      canvas.translate(top.dx, top.dy);
      canvas.rotate(side * 0.9 + sway);
      canvas.drawOval(Rect.fromLTWH(-u * 0.05, -u * 0.17, u * 0.10, u * 0.17), Paint()..color = green);
      canvas.restore();
    }
  }

  void _voice(Canvas canvas, Offset c, double u, double t, bool moving) {
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = u * 0.03;
    for (var i = 0; i < 3; i++) {
      final alpha = moving ? 0.25 + 0.6 * (0.5 + 0.5 * math.sin((t * 4 - i * 0.22) * 2 * math.pi)) : 0.7;
      wave.color = const Color(0xFF1F4FD1).withValues(alpha: alpha);
      final r = u * (0.10 + 0.09 * i);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -0.7, 1.4, false, wave);
    }
  }

  void _glow(Canvas canvas, Offset c, double u, double t, bool moving) {
    final pulse = moving ? 0.5 + 0.5 * math.sin(t * 2 * math.pi) : 0.5;
    final r = u * (1.25 + 0.06 * pulse);
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = RadialGradient(colors: [const Color(0x55FFE45C), const Color(0x22B58CFF), const Color(0x00B58CFF)], stops: const [0.55, 0.85, 1]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant PetPainter old) => old.time != time || old.pet != pet || old.fit != fit;
}
