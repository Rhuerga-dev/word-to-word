import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../data/pet.dart';
import 'pet_cloud.dart';
import 'pet_texts.dart';

/// Brainy: una criatura redonda con una cúpula de cristal en la cabeza; dentro se ve su cerebro, una nube de
/// neuronas. Diseño propio, dibujado con código (sin imágenes), del color que elija el alumno.
///
/// - Nace pequeña, de color neutro, con los ojos cerrados y TODAS las neuronas blancas.
/// - Al aprender, cada zona del cerebro se enciende con su color, y por las conexiones viajan señales.
/// - Crece con cada etapa: abre los ojos, le salen brazos y pies, voz y, al final, brilla.
/// - Respira y parpadea; con «Reducir movimiento» se queda quieta.
/// - Con cuidados (pet.care) su cara cambia: duerme, tiene hambre, quiere jugar, hay desorden o está malita.
/// - De adulta toma una forma según lo que más practicas (orejas, voz doble, gafas o una estrella).
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
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 6))..addListener(_tick);

  /// Las señales que viajan por el cerebro. En figuras pequeñas van menos: no se distinguirían.
  late final BrainSignals _signals = BrainSignals(count: widget.size < 120 ? 12 : 30);
  double _last = 0;

  /// Cada cuadro, las señales avanzan el tiempo que pasó (el reloj da vueltas de 0 a 1 cada 6 s).
  void _tick() {
    var d = _clock.value - _last;
    if (d < 0) d += 1;
    _last = _clock.value;
    _signals.step(d * 6);
  }

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
          child: AnimatedBuilder(
            animation: _clock,
            builder: (_, __) => CustomPaint(painter: PetPainter(p, _clock.isAnimating ? _clock.value : null, fit: widget.fit, signals: _clock.isAnimating ? _signals : null)),
          ),
        ),
      ),
    );
  }
}

/// Dibuja la mascota. [time] va de 0 a 1 en bucle; null = quieta.
///
/// Está pensada en una hoja de 400 × 420 (los pies en y = 392) que se escala al tamaño pedido.
class PetPainter extends CustomPainter {
  PetPainter(this.pet, this.time, {this.fit = false, this.signals});
  final PetState pet;
  final double? time;
  final bool fit;

  /// Las señales del cerebro (null = quieta: se dibuja sin ellas).
  final BrainSignals? signals;

  /// Cuánto mide la criatura en cada etapa respecto a la adulta (nace pequeña).
  static const stageScale = [0.62, 0.74, 0.84, 0.92, 1.0];

  /// A qué zona de lo que aprendes corresponde cada región del cerebro (0…4).
  static const regionOf = [PetRegion.path, PetRegion.memory, PetRegion.habit, PetRegion.words, PetRegion.links];

  static const _ink = Color(0xFF0B1238);

  static Color _shade(Color c, double lightness, [double saturation = 0]) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + lightness).clamp(0.0, 1.0)).withSaturation((h.saturation + saturation).clamp(0.0, 1.0)).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time ?? 0.0, moving = time != null;
    final stage = pet.stage.clamp(0, 4);
    final care = pet.care;
    final mood = care?.mood ?? '';
    final resting = care?.resting ?? false;
    final form = stage >= 4 ? care?.form : null;
    final color = BrainyColors.of(pet.color);

    // De la hoja de 400 × 420 al cuadro pedido (con un poco de aire para el brillo, las zetas y la estrella).
    final s = size.shortestSide / 452;
    canvas.save();
    canvas.translate((size.width - 400 * s) / 2, (size.height - 420 * s) / 2 + 6 * s);
    canvas.scale(s);

    final k = fit ? 1.0 : stageScale[stage];
    final breath = moving ? 1 + 0.012 * math.sin(t * 2 * math.pi * 2) : 1.0;
    if (stage >= 4) _glow(canvas, k, t, moving);
    canvas.drawOval(Rect.fromCenter(center: const Offset(200, 396), width: 192 * k, height: 22 * k), Paint()..color = const Color(0x40050A2A));

    // Todo lo demás crece desde los pies.
    canvas.translate(200, 392);
    canvas.scale(k * breath);
    canvas.translate(-200, -392);

    final light = _shade(color, 0.16), dark = _shade(color, -0.20), darker = _shade(color, -0.27);

    // Forma «orejona»: dos orejas grandes a los lados de la cabeza (detrás del cuerpo).
    if (form == 'listener') {
      for (final side in [-1.0, 1.0]) {
        final ear = Rect.fromCenter(center: Offset(200 + side * 118, 176), width: 50, height: 78);
        canvas.drawOval(ear, Paint()..color = dark);
        canvas.drawOval(ear.deflate(11), Paint()..color = const Color(0x88FF8FB1));
      }
    }

    // Antena con la chispa de la que nació.
    canvas.drawPath(
      Path()
        ..moveTo(200, 120)
        ..cubicTo(200, 108, 196, 100, 200, 90),
      Paint()
        ..color = _shade(color, 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    final pulse = moving ? 0.5 + 0.5 * math.sin(t * 2 * math.pi * 3) : 0.5;
    final sparkGlow = 26 + 6 * pulse;
    canvas.drawCircle(const Offset(200, 78), sparkGlow, Paint()..shader = ui.Gradient.radial(const Offset(200, 78), sparkGlow, [const Color(0xE6FFE45C), const Color(0x00FFE45C)]));
    canvas.drawCircle(const Offset(200, 78), stage == 0 ? 15 : 11, Paint()..color = const Color(0xFFFFE45C));
    canvas.drawCircle(const Offset(196, 74), 4, Paint()..color = const Color(0xE6FFFFFF));
    // Forma «equilibrada»: una estrella sobre la chispa.
    if (form == 'balanced') _star(canvas, const Offset(200, 36), 15, t, moving);

    // Pies y brazos (desde «Aprendiz»).
    if (stage >= 2) {
      final foot = Paint()..color = darker;
      canvas.drawOval(Rect.fromCenter(center: const Offset(160, 378), width: 60, height: 30), foot);
      canvas.drawOval(Rect.fromCenter(center: const Offset(240, 378), width: 60, height: 30), foot);
      final limb = Paint()..shader = ui.Gradient.linear(const Offset(0, -36), const Offset(0, 36), [_shade(color, 0.04), dark]);
      final wave = moving && !resting ? 0.10 * math.sin(t * 2 * math.pi * 3) : 0.0;
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(200 + side * 112, 272);
        canvas.rotate(-side * (18 * math.pi / 180 + wave));
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 38, height: 72), limb);
        canvas.restore();
      }
    }
    // Desorden: unas motas de polvo junto a los pies.
    if (mood == 'messy') {
      final dust = Paint()..color = const Color(0x99A0855B);
      for (final (x, y, r) in const [(92.0, 372.0, 9.0), (112.0, 388.0, 6.0), (306.0, 376.0, 8.0), (286.0, 390.0, 5.0), (326.0, 390.0, 4.5)]) {
        canvas.drawCircle(Offset(x, y), r, dust);
      }
    }

    // Cuerpo.
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(86, 106, 228, 272), const Radius.circular(112));
    canvas.drawRRect(body, Paint()..shader = ui.Gradient.linear(const Offset(200, 100), const Offset(200, 380), [light, color, dark], const [0, 0.45, 1]));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(200, 318), width: 160, height: 116),
      Paint()..shader = ui.Gradient.radial(const Offset(200, 318), 80, [Colors.white.withValues(alpha: 0.30), Colors.white.withValues(alpha: 0)]),
    );

    // Cúpula de cristal con el cerebro dentro.
    final dome = RRect.fromRectAndRadius(const Rect.fromLTWH(110, 120, 180, 118), const Radius.circular(59));
    canvas.drawRRect(dome, Paint()..shader = ui.Gradient.radial(const Offset(200, 170), 110, [const Color(0xFF1B2760), const Color(0xFF070B24)]));
    canvas.save();
    canvas.clipRRect(dome.deflate(3));
    _brain(canvas, const Offset(200, 181), 73);
    canvas.restore();
    canvas.drawRRect(
      dome,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _shade(color, 0.34).withValues(alpha: 0.85),
    );
    canvas.drawPath(
      Path()
        ..moveTo(128, 164)
        ..cubicTo(132, 142, 150, 130, 172, 128),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(184, 128), 3, Paint()..color = Colors.white.withValues(alpha: 0.55));

    _face(canvas, t, moving, stage, mood, resting, form == 'scholar');

    // Voz (desde «Voz»): ondas junto a la boca. Dormida no habla. La «parlanchina» habla por los dos lados.
    if (stage >= 3 && !resting) {
      _voice(canvas, const Offset(322, 322), t, moving, color);
      if (form == 'talker') _voice(canvas, const Offset(78, 322), t, moving, color, left: true);
    }
    if (resting) _zzz(canvas, const Offset(302, 112), t, moving);
    canvas.restore();
  }

  /// El cerebro: una nube de neuronas. Las que aún no se han aprendido son BLANCAS; las aprendidas toman el
  /// color de su zona y brillan. Las señales viajan por todas, con estela dorada entre las encendidas.
  /// [c] = centro, [r] = cuánto mide «1» del cerebro en la hoja.
  void _brain(Canvas canvas, Offset c, double r) {
    final m = BrainCloud.instance;
    final levels = [for (final region in regionOf) pet.level(region)];
    bool on(int i) => m.threshold[i] < levels[m.region[i]];

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(r);
    final u = 1 / r; // una unidad de la hoja, en unidades del cerebro

    // Conexiones, todas de una vez.
    canvas.drawRawPoints(
      ui.PointMode.lines,
      m.lines,
      Paint()
        ..color = const Color(0xFFB9CBFF).withValues(alpha: 0.13)
        ..strokeWidth = 0.6 * u,
    );

    // Neuronas, agrupadas para dibujarlas deprisa: blancas por capa de profundidad, encendidas por zona y capa.
    final white = List.generate(3, (_) => <double>[]);
    final lit = List.generate(5, (_) => List.generate(3, (_) => <double>[]));
    for (var i = 0; i < m.count; i++) {
      (on(i) ? lit[m.region[i]][m.band[i]] : white[m.band[i]])
        ..add(m.sx[i])
        ..add(m.sy[i]);
    }
    final dots = Paint()..strokeCap = StrokeCap.round;
    for (var b = 0; b < 3; b++) {
      if (white[b].isEmpty) continue;
      dots
        ..color = Colors.white.withValues(alpha: 0.34 + 0.22 * b)
        ..strokeWidth = (1.8 + 0.7 * b) * u;
      canvas.drawRawPoints(ui.PointMode.points, Float32List.fromList(white[b]), dots);
    }
    for (var p = 0; p < 5; p++) {
      final base = petColors[regionOf[p]]!;
      for (var b = 0; b < 3; b++) {
        if (lit[p][b].isEmpty) continue;
        final pts = Float32List.fromList(lit[p][b]);
        dots
          ..color = base.withValues(alpha: 0.22)
          ..strokeWidth = (5.4 + 1.6 * b) * u; // halo: la encendida brilla
        canvas.drawRawPoints(ui.PointMode.points, pts, dots);
        dots
          ..color = base.withValues(alpha: 0.60 + 0.20 * b)
          ..strokeWidth = (2.5 + 1.0 * b) * u;
        canvas.drawRawPoints(ui.PointMode.points, pts, dots);
      }
    }

    final sig = signals;
    if (sig != null) {
      // El destello de la neurona a la que acaba de llegar una señal.
      final flash = Paint();
      for (var i = 0; i < m.count; i++) {
        final g = sig.glow[i];
        if (g <= 0.02) continue;
        flash.color = (on(i) ? Color.lerp(petColors[regionOf[m.region[i]]]!, Colors.white, 0.75)! : Colors.white).withValues(alpha: 0.75 * g);
        canvas.drawCircle(Offset(m.sx[i], m.sy[i]), (1.4 + 1.8 * g) * u, flash);
      }
      final trail = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.5 * u;
      final head = Paint()..color = Colors.white;
      final halo = Paint()..color = const Color(0xFFFFE45C).withValues(alpha: 0.35);
      for (var i = 0; i < sig.length; i++) {
        final e = sig.edge(i);
        final ia = sig.forward(i) ? m.edgeA[e] : m.edgeB[e], ib = sig.forward(i) ? m.edgeB[e] : m.edgeA[e];
        final from = Offset(m.sx[ia], m.sy[ia]), to = Offset(m.sx[ib], m.sy[ib]);
        final p = Offset.lerp(from, to, sig.t(i))!, tail = Offset.lerp(from, to, math.max(0, sig.t(i) - 0.55))!;
        final bright = on(ia) && on(ib);
        if ((p - tail).distance > 0.3 * u) {
          trail.shader = ui.Gradient.linear(tail, p, bright ? [const Color(0x00FFE45C), const Color(0xE6FFF3B0)] : [const Color(0x00FFFFFF), const Color(0x80FFFFFF)]);
          canvas.drawLine(tail, p, trail);
        }
        if (bright) canvas.drawCircle(p, 3.2 * u, halo);
        canvas.drawCircle(p, (bright ? 1.5 : 1.0) * u, head);
      }
    }
    canvas.restore();
  }

  void _face(Canvas canvas, double t, bool moving, int stage, String mood, bool resting, bool glasses) {
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    // Mejillas (verdosas si está malita).
    final cheek = Paint()..color = mood == 'sick' ? const Color(0x994AC487) : const Color(0x99FF8FB1);
    canvas.drawOval(Rect.fromCenter(center: const Offset(136, 306), width: 30, height: 20), cheek);
    canvas.drawOval(Rect.fromCenter(center: const Offset(264, 306), width: 30, height: 20), cheek);

    // Ojos. Recién nacida: cerrados y contentos. Dormida: cerrados hacia abajo. Después, abiertos y con parpadeo.
    final blink = moving && (t * 6) % 3 > 2.9;
    final lookUp = mood == 'hungry' ? -5.0 : 0.0; // con hambre mira hacia arriba, pensando en comida
    for (final cx in [164.0, 236.0]) {
      if (resting) {
        canvas.drawPath(
          Path()
            ..moveTo(cx - 15, 282)
            ..quadraticBezierTo(cx, 296, cx + 15, 282),
          white,
        );
      } else if (stage == 0 || blink) {
        canvas.drawPath(
          Path()
            ..moveTo(cx - 15, 290)
            ..quadraticBezierTo(cx, 272, cx + 15, 290),
          white,
        );
      } else {
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, 284), width: 34, height: 40), Paint()..color = Colors.white);
        canvas.drawCircle(Offset(cx, 288 + lookUp), 11, Paint()..color = _ink);
        canvas.drawCircle(Offset(cx + 4, 283 + lookUp), 4.2, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(cx - 4, 293 + lookUp), 2, Paint()..color = Colors.white.withValues(alpha: 0.8));
      }
    }
    // Gafas (forma «sabia»).
    if (glasses && !resting) {
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFFFD84A);
      canvas.drawCircle(const Offset(164, 284), 27, rim);
      canvas.drawCircle(const Offset(236, 284), 27, rim);
      canvas.drawLine(const Offset(191, 284), const Offset(209, 284), rim);
    }
    // Boca.
    if (resting) {
      canvas.drawCircle(const Offset(200, 322), 5, Paint()..color = Colors.white); // boquita dormida
    } else if (mood == 'hungry') {
      canvas.drawOval(Rect.fromCenter(center: const Offset(200, 324), width: 18, height: 22), Paint()..color = _ink); // «¡comida!»
    } else if (mood == 'sick') {
      canvas.drawPath(
        Path()
          ..moveTo(180, 322)
          ..quadraticBezierTo(190, 312, 200, 322)
          ..quadraticBezierTo(210, 332, 220, 322),
        white,
      );
    } else if (mood == 'bored' || mood == 'messy') {
      canvas.drawLine(const Offset(186, 322), const Offset(214, 322), white); // boca recta
    } else if (stage == 0) {
      canvas.drawPath(
        Path()
          ..moveTo(192, 320)
          ..quadraticBezierTo(200, 324, 208, 320),
        white..strokeWidth = 4.5,
      );
    } else if (stage >= 3) {
      // Desde «Voz», sonrisa abierta: está hablando.
      canvas.drawPath(
        Path()
          ..moveTo(182, 312)
          ..quadraticBezierTo(200, 306, 218, 312)
          ..quadraticBezierTo(218, 338, 200, 338)
          ..quadraticBezierTo(182, 338, 182, 312)
          ..close(),
        Paint()..color = _ink,
      );
      canvas.drawOval(Rect.fromCenter(center: const Offset(200, 331), width: 20, height: 12), Paint()..color = const Color(0xFFFF8FB1));
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(182, 314)
          ..quadraticBezierTo(200, 334, 218, 314),
        white,
      );
    }
  }

  /// Tres zetas que suben: duerme.
  void _zzz(Canvas canvas, Offset c, double t, bool moving) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5;
    for (var i = 0; i < 3; i++) {
      final rise = moving ? ((t * 2 + i / 3) % 1) : i / 3;
      final s = 11 + 8 * rise;
      final o = c + Offset(32 * rise + 10 * i, -58 * rise);
      pen.color = const Color(0xFFB9CBFF).withValues(alpha: 0.95 - 0.7 * rise);
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - s, o.dy - s)
          ..lineTo(o.dx + s, o.dy - s)
          ..lineTo(o.dx - s, o.dy + s)
          ..lineTo(o.dx + s, o.dy + s),
        pen,
      );
    }
  }

  void _star(Canvas canvas, Offset c, double r, double t, bool moving) {
    final k = moving ? 0.85 + 0.15 * math.sin(t * 2 * math.pi * 2) : 1.0;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final d = (i.isEven ? r : r * 0.40) * k;
      final p = c + Offset(math.cos(a) * d, math.sin(a) * d);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = const Color(0xFFFFD84A));
  }

  void _voice(Canvas canvas, Offset c, double t, bool moving, Color color, {bool left = false}) {
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    for (var i = 0; i < 3; i++) {
      final alpha = moving ? 0.25 + 0.6 * (0.5 + 0.5 * math.sin((t * 4 - i * 0.22) * 2 * math.pi)) : 0.7;
      wave.color = _shade(color, 0.22).withValues(alpha: alpha);
      final r = 14.0 + 12 * i;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), left ? math.pi - 0.7 : -0.7, 1.4, false, wave);
    }
  }

  /// El brillo de la última etapa: un aura detrás de toda la figura.
  void _glow(Canvas canvas, double k, double t, bool moving) {
    final pulse = moving ? 0.5 + 0.5 * math.sin(t * 2 * math.pi) : 0.5;
    final r = (200 + 8 * pulse) * k;
    final c = Offset(200, 392 - 160 * k);
    canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c, r, [const Color(0x55FFE45C), const Color(0x22B58CFF), const Color(0x00B58CFF)], const [0.55, 0.85, 1]));
  }

  @override
  bool shouldRepaint(covariant PetPainter old) => old.time != time || old.pet != pet || old.fit != fit;
}
