import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// PRUEBA (aún no se usa en la app): el personaje nuevo de Brainy, dibujado con código.
///
/// - El cuerpo toma el color que elija el alumno ([BrainyColors]); recién nacida es de color neutro.
/// - Dentro de la cúpula va el mismo cerebro del panel de Huerga Labs (neuronas en 3D, vistas desde un
///   ángulo fijo). No gira: lo que se mueve son las SEÑALES, que viajan de neurona en neurona por sus conexiones.
///
/// Sin imágenes: todo son formas, así cabe en un parche de Shorebird.

/// Colores para elegir. El primero es el neutro con el que nace.
class BrainyColors {
  static const neutral = Color(0xFFB8C0D0);
  static const choices = <(String, Color)>[
    ('Azul', Color(0xFF3F5BEA)),
    ('Morado', Color(0xFF8B5CF6)),
    ('Rosa', Color(0xFFEC5C9A)),
    ('Coral', Color(0xFFF2694B)),
    ('Naranja', Color(0xFFF39A2B)),
    ('Verde', Color(0xFF2FB36F)),
    ('Turquesa', Color(0xFF17A9B8)),
  ];
}

/// Los colores de las cinco regiones del cerebro (los mismos del panel).
const brainRegionColors = [Color(0xFF7C9CFF), Color(0xFF4AC487), Color(0xFFE6A64A), Color(0xFFF07A9A), Color(0xFFB58CFF)];

/// El cerebro: neuronas con su posición ya proyectada a la pantalla y sus conexiones. Se construye una vez.
/// Es la misma receta del panel (public/js/brain.js en huergalabs-admin), con menos neuronas para el teléfono.
class BrainModel {
  BrainModel._(this.count) {
    _build();
  }

  static final BrainModel instance = BrainModel._(680);

  final int count;
  late final Float32List sx, sy, depth; // posición en pantalla (−1…1) y profundidad (0 = lejos, 1 = cerca)
  late final Uint8List region; // 0…4
  late final Uint16List edgeA, edgeB;
  late final List<List<int>> edgesOf; // conexiones que tocan cada neurona

  /// Azar con semilla (mulberry32): el cerebro sale igual en todos los teléfonos.
  static double Function() _seeded(int seed) {
    var s = seed;
    return () {
      s = (s + 0x6D2B79F5) & 0xFFFFFFFF;
      var t = _imul(s ^ (s >>> 15), 1 | s);
      t = ((t + _imul(t ^ (t >>> 7), 61 | t)) & 0xFFFFFFFF) ^ t;
      return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
    };
  }

  static int _imul(int a, int b) => ((a & 0xFFFFFFFF) * (b & 0xFFFFFFFF)) & 0xFFFFFFFF;

  void _build() {
    final rand = _seeded(20261117);
    final xs = <double>[], ys = <double>[], zs = <double>[], ph = <int>[];
    List<double> direction() {
      final u = rand() * 2 - 1, a = rand() * math.pi * 2, s = math.sqrt(1 - u * u);
      return [s * math.cos(a), u, s * math.sin(a)];
    }

    double groove(double x, double y, double z) {
      final n = math.sin(11 * x + 3 * math.sin(4 * z)) + math.sin(9 * z + 2.5 * math.sin(5 * y)) + math.sin(10 * y + 2 * math.sin(6 * x));
      return math.exp(-math.pow(n / 0.35, 2).toDouble());
    }

    // Corteza (dos hemisferios) y núcleo. Ejes: x = izquierda/derecha, y = arriba, z = delante/atrás.
    while (xs.length < count * 0.80) {
      final d = direction();
      final deep = rand() < 0.2;
      final r = deep ? 0.25 + 0.6 * rand() : 0.93 + 0.07 * rand();
      var x = d[0] * 0.74 * r, y = d[1] * 0.62 * r, z = d[2] * r;
      if (!deep) {
        final g = groove(x, y, z);
        if (g > 0.55 && rand() < 0.75) continue; // el surco se ve porque ahí hay menos neuronas
        final k = 1 - 0.07 * g;
        x *= k;
        y *= k;
        z *= k;
      }
      if (y < 0) y *= 0.72;
      x *= 1 - 0.13 * z;
      final ax = x.abs();
      if (y > -0.1) y -= 0.16 * math.exp(-math.pow(ax / 0.1, 2).toDouble());
      x = (x < 0 ? -1 : 1) * (ax * 0.93 + 0.045);
      final int p;
      if (deep && r < 0.6) {
        p = 4;
      } else if (z < -0.42) {
        p = 0;
      } else if (y < -0.1 && ax > 0.28 && z < 0.5) {
        p = 2;
      } else if (z > 0.18) {
        p = 3;
      } else {
        p = 1;
      }
      xs.add(x);
      ys.add(y);
      zs.add(z);
      ph.add(p);
    }
    // Lóbulos temporales y cerebelo (sin tronco: dentro de la cúpula no cabe y no hace falta).
    while (xs.length < count * 0.90) {
      final d = direction();
      final r = 0.85 + 0.15 * rand(), side = rand() < 0.5 ? -1 : 1;
      xs.add(side * 0.5 + d[0] * 0.17 * r);
      ys.add(-0.3 + d[1] * 0.15 * r);
      zs.add(0.12 + d[2] * 0.42 * r);
      ph.add(2);
    }
    while (xs.length < count) {
      final d = direction();
      final r = rand() < 0.25 ? 0.4 + 0.5 * rand() : 0.94 + 0.06 * rand();
      xs.add(d[0] * 0.46 * r);
      ys.add(-0.46 + d[1] * 0.2 * r);
      zs.add(-0.6 + d[2] * 0.27 * r);
      ph.add(4);
    }

    // Vista fija de tres cuartos (como abre el panel): se gira una vez y ya no se mueve.
    const yaw = -1.05, pitch = 0.20;
    final cy = math.cos(yaw), syw = math.sin(yaw), cp = math.cos(pitch), sp = math.sin(pitch);
    final n = xs.length;
    sx = Float32List(n);
    sy = Float32List(n);
    depth = Float32List(n);
    region = Uint8List.fromList(ph);
    final rx = Float32List(n), ry = Float32List(n), rz = Float32List(n);
    for (var i = 0; i < n; i++) {
      final x1 = xs[i] * cy + zs[i] * syw, z1 = -xs[i] * syw + zs[i] * cy;
      final y2 = ys[i] * cp - z1 * sp, z2 = ys[i] * sp + z1 * cp;
      rx[i] = x1;
      ry[i] = y2;
      rz[i] = z2;
      final persp = 2.6 / (2.6 - z2); // un poco de perspectiva: lo cercano, más grande
      sx[i] = x1 * persp;
      sy[i] = -y2 * persp;
      depth[i] = ((z2 + 1) / 2).clamp(0.0, 1.0);
    }

    // Conexiones: cada neurona con sus 2 vecinas más cercanas (en 3D).
    final a = <int>[], b = <int>[];
    final seen = <int>{};
    for (var i = 0; i < n; i++) {
      var b1 = -1, b2 = -1;
      var d1 = double.infinity, d2 = double.infinity;
      for (var j = 0; j < n; j++) {
        if (j == i) continue;
        final dx = rx[i] - rx[j], dy = ry[i] - ry[j], dz = rz[i] - rz[j];
        final d = dx * dx + dy * dy + dz * dz;
        if (d < d1) {
          b2 = b1;
          d2 = d1;
          b1 = j;
          d1 = d;
        } else if (d < d2) {
          b2 = j;
          d2 = d;
        }
      }
      for (final j in [b1, b2]) {
        if (j < 0) continue;
        final k = i < j ? i * n + j : j * n + i;
        if (seen.add(k)) {
          a.add(i);
          b.add(j);
        }
      }
    }
    edgeA = Uint16List.fromList(a);
    edgeB = Uint16List.fromList(b);
    edgesOf = List.generate(n, (_) => <int>[]);
    for (var e = 0; e < a.length; e++) {
      edgesOf[a[e]].add(e);
      edgesOf[b[e]].add(e);
    }
  }
}

/// Las señales que viajan por el cerebro. Cada una recorre una conexión y, al llegar a la neurona,
/// la enciende un instante y sigue por otra conexión de esa misma neurona: así se ven «caminos».
class BrainSignals {
  BrainSignals({this.count = 34, int seed = 7}) : _rand = math.Random(seed) {
    final m = BrainModel.instance;
    glow = Float32List(m.count);
    for (var i = 0; i < count; i++) {
      final e = _rand.nextInt(m.edgeA.length);
      _edge.add(e);
      _forward.add(_rand.nextBool());
      _t.add(_rand.nextDouble());
      _speed.add(1.1 + _rand.nextDouble() * 1.5);
    }
  }

  final int count;
  final math.Random _rand;
  final _edge = <int>[], _forward = <bool>[], _t = <double>[], _speed = <double>[];

  /// Cuánto brilla cada neurona por una señal que acaba de llegar (1 → 0).
  late final Float32List glow;

  int get length => _edge.length;
  int edge(int i) => _edge[i];
  bool forward(int i) => _forward[i];
  double t(int i) => _t[i];

  /// Avanza [dt] segundos.
  void step(double dt) {
    final m = BrainModel.instance;
    for (var i = 0; i < glow.length; i++) {
      if (glow[i] > 0) glow[i] = math.max(0, glow[i] - dt * 2.2);
    }
    for (var i = 0; i < _edge.length; i++) {
      _t[i] += dt * _speed[i];
      if (_t[i] < 1) continue;
      final e = _edge[i];
      final arrived = _forward[i] ? m.edgeB[e] : m.edgeA[e];
      glow[arrived] = 1;
      // Sigue por otra conexión de la neurona a la que llegó (si solo tiene esta, da media vuelta).
      final options = m.edgesOf[arrived];
      var next = options[_rand.nextInt(options.length)];
      if (next == e && options.length > 1) next = options[(options.indexOf(e) + 1) % options.length];
      _edge[i] = next;
      _forward[i] = m.edgeA[next] == arrived;
      _t[i] = 0;
    }
  }
}

/// Qué expresión tiene.
enum BrainyPose { main, newborn }

/// El personaje. [color] es el del cuerpo; [lit] (0–1) cuánto cerebro está encendido; [signals] las señales.
class BrainyCharacterPainter extends CustomPainter {
  BrainyCharacterPainter({required this.color, this.pose = BrainyPose.main, this.lit = 1, this.signals, this.blink = 0, super.repaint});

  final Color color;
  final BrainyPose pose;
  final double lit;
  final BrainSignals? signals;

  /// 0 = ojos abiertos, 1 = cerrados (parpadeo).
  final double blink;

  static Color _shade(Color c, double lightness, [double saturation = 0]) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + lightness).clamp(0.0, 1.0)).withSaturation((h.saturation + saturation).clamp(0.0, 1.0)).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // El dibujo está pensado en una hoja de 400 × 420 (la de Figma) y se escala al tamaño pedido.
    final s = math.min(size.width / 400, size.height / 420);
    canvas.save();
    canvas.translate((size.width - 400 * s) / 2, (size.height - 420 * s) / 2);
    canvas.scale(s);

    final newborn = pose == BrainyPose.newborn;
    final k = newborn ? 0.62 : 1.0;
    canvas.drawOval(Rect.fromCenter(center: const Offset(200, 396), width: 192 * k, height: 22 * k), Paint()..color = const Color(0x59050A2A));
    canvas.translate(200, 392);
    canvas.scale(k);
    canvas.translate(-200, -392);

    final light = _shade(color, 0.16), dark = _shade(color, -0.20), darker = _shade(color, -0.27);
    final limb = Paint()..shader = ui.Gradient.linear(const Offset(0, 150), const Offset(0, 320), [_shade(color, 0.04), dark]);

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
    canvas.drawCircle(const Offset(200, 78), 30, Paint()..shader = ui.Gradient.radial(const Offset(200, 78), 30, [const Color(0xE6FFE45C), const Color(0x00FFE45C)]));
    canvas.drawCircle(const Offset(200, 78), newborn ? 15 : 11, Paint()..color = const Color(0xFFFFE45C));
    canvas.drawCircle(const Offset(196, 74), 4, Paint()..color = const Color(0xE6FFFFFF));

    if (!newborn) {
      // Pies y brazos.
      final foot = Paint()..color = darker;
      canvas.drawOval(Rect.fromCenter(center: const Offset(160, 378), width: 60, height: 30), foot);
      canvas.drawOval(Rect.fromCenter(center: const Offset(240, 378), width: 60, height: 30), foot);
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(200 + side * 112, 272);
        canvas.rotate(-side * 18 * math.pi / 180);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 38, height: 72), limb);
        canvas.restore();
      }
    }

    // Cuerpo.
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(86, 106, 228, 272), const Radius.circular(112));
    canvas.drawRRect(body, Paint()..shader = ui.Gradient.linear(const Offset(200, 100), const Offset(200, 380), [light, color, dark], const [0, 0.45, 1]));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(200, 318), width: 160, height: 116),
      Paint()..shader = ui.Gradient.radial(const Offset(200, 318), 80, [Colors.white.withValues(alpha: 0.30), Colors.white.withValues(alpha: 0)]),
    );

    // Cúpula de cristal.
    final dome = RRect.fromRectAndRadius(const Rect.fromLTWH(110, 120, 180, 118), const Radius.circular(59));
    canvas.drawRRect(dome, Paint()..shader = ui.Gradient.radial(const Offset(200, 170), 110, [const Color(0xFF1B2760), const Color(0xFF070B24)]));
    canvas.save();
    canvas.clipRRect(dome.deflate(3));
    _paintBrain(canvas, const Offset(200, 181), 62);
    canvas.restore();
    canvas.drawRRect(
      dome,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _shade(color, 0.34).withValues(alpha: 0.85),
    );
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(128, 164)
        ..cubicTo(132, 142, 150, 130, 172, 128),
      shine,
    );
    canvas.drawCircle(const Offset(184, 128), 3, Paint()..color = Colors.white.withValues(alpha: 0.55));

    // Cara.
    final cheek = Paint()..color = const Color(0x99FF8FB1);
    canvas.drawOval(Rect.fromCenter(center: const Offset(136, 306), width: 30, height: 20), cheek);
    canvas.drawOval(Rect.fromCenter(center: const Offset(264, 306), width: 30, height: 20), cheek);
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    final closed = newborn ? 1.0 : blink;
    for (final cx in [164.0, 236.0]) {
      if (closed > 0.85) {
        canvas.drawPath(
          Path()
            ..moveTo(cx - 15, 284)
            ..quadraticBezierTo(cx, 298, cx + 15, 284),
          white,
        );
      } else {
        final ry = 20 * (1 - closed);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, 284), width: 34, height: ry * 2), Paint()..color = Colors.white);
        canvas.save();
        canvas.clipRect(Rect.fromCenter(center: Offset(cx, 284), width: 34, height: ry * 2));
        canvas.drawCircle(Offset(cx, 288), 11, Paint()..color = const Color(0xFF0B1238));
        canvas.drawCircle(Offset(cx + 4, 283), 4.2, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(cx - 4, 293), 2, Paint()..color = Colors.white.withValues(alpha: 0.8));
        canvas.restore();
      }
    }
    if (newborn) {
      canvas.drawPath(
        Path()
          ..moveTo(192, 320)
          ..quadraticBezierTo(200, 324, 208, 320),
        white..strokeWidth = 4.5,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(182, 314)
          ..quadraticBezierTo(200, 334, 218, 314),
        white,
      );
    }
    canvas.restore();
  }

  /// El cerebro dentro de la cúpula: conexiones tenues, neuronas por región y las señales viajando.
  void _paintBrain(Canvas canvas, Offset c, double r) {
    final m = BrainModel.instance;
    Offset at(int i) => Offset(c.dx + m.sx[i] * r * 1.18, c.dy + m.sy[i] * r * 1.18);
    final onCount = (m.count * lit).round();
    bool on(int i) => i < onCount; // prueba: el orden hace de «umbral» (en la app será el progreso de cada región)

    // Conexiones.
    final lines = Paint()
      ..color = const Color(0xFFB9CBFF).withValues(alpha: 0.13)
      ..strokeWidth = 0.6;
    for (var e = 0; e < m.edgeA.length; e++) {
      canvas.drawLine(at(m.edgeA[e]), at(m.edgeB[e]), lines);
    }
    // Neuronas: las de atrás, más pequeñas y tenues.
    final dot = Paint();
    for (var i = 0; i < m.count; i++) {
      final lightUp = signals?.glow[i] ?? 0;
      final d = m.depth[i];
      if (!on(i)) {
        dot.color = const Color(0xFF3A4660).withValues(alpha: 0.5 + 0.3 * d);
        canvas.drawCircle(at(i), 0.9 + 0.5 * d, dot);
        continue;
      }
      final base = brainRegionColors[m.region[i]];
      dot.color = Color.lerp(base, Colors.white, 0.75 * lightUp)!.withValues(alpha: (0.35 + 0.6 * d + 0.4 * lightUp).clamp(0.0, 1.0));
      canvas.drawCircle(at(i), 0.9 + 0.9 * d + 1.6 * lightUp, dot);
    }
    // Señales: una cabeza brillante con su estela.
    final sig = signals;
    if (sig == null) return;
    final trail = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    final head = Paint()..color = Colors.white;
    final halo = Paint()..color = const Color(0xFFFFE45C).withValues(alpha: 0.35);
    for (var i = 0; i < sig.length; i++) {
      final e = sig.edge(i);
      final from = at(sig.forward(i) ? m.edgeA[e] : m.edgeB[e]), to = at(sig.forward(i) ? m.edgeB[e] : m.edgeA[e]);
      final p = Offset.lerp(from, to, sig.t(i))!, tail = Offset.lerp(from, to, math.max(0, sig.t(i) - 0.55))!;
      trail.shader = ui.Gradient.linear(tail, p, [const Color(0x00FFE45C), const Color(0xE6FFF3B0)]);
      canvas.drawLine(tail, p, trail);
      canvas.drawCircle(p, 3.2, halo);
      canvas.drawCircle(p, 1.5, head);
    }
  }

  @override
  bool shouldRepaint(BrainyCharacterPainter old) => true;
}
