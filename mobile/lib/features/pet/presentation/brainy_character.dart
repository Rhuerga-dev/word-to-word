import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// PRUEBA (aún no se usa en la app): el personaje nuevo de Brainy, dibujado con código.
///
/// - El cuerpo toma el color que elija el alumno ([BrainyColors]); recién nacida es de color neutro.
/// - Dentro de la cúpula va un cerebro bien definido (silueta y surcos, cada región de un color). No gira:
///   lo que se mueve son las SEÑALES, que viajan de neurona en neurona por los surcos.
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

/// El cerebro que se ve dentro de la cúpula: una silueta con sus surcos bien marcados (visto de frente, con
/// los dos hemisferios). Cada surco pertenece a una región y lleva sus neuronas; las neuronas vecinas están
/// conectadas, también de un surco a otro, para que las señales puedan recorrer todo el cerebro.
/// Coordenadas en una hoja propia: centro (0, 0), ancho ≈ 244, alto ≈ 200. Se construye una sola vez.
class BrainModel {
  BrainModel._() {
    _build();
  }

  static final BrainModel instance = BrainModel._();

  /// Medio ancho y medio alto de la silueta (para encajarla donde haga falta).
  static const halfWidth = 136.0, halfHeight = 112.0;

  late final Path outline; // la silueta, con sus «bultos»
  late final List<Path> folds; // los surcos
  late final List<int> foldRegion; // región (0…4) de cada surco
  late final int count; // neuronas
  late final Float32List x, y;
  late final Uint8List region;
  late final Uint16List edgeA, edgeB;
  late final List<List<int>> edgesOf; // conexiones que tocan cada neurona

  /// Los surcos del hemisferio izquierdo (el derecho es su espejo): puntos de curvas Bézier y su región.
  static const _left = <(List<double>, int)>[
    ([-82, -78, -66, -92, -50, -74, -30, -88], 3),
    ([-96, -38, -76, -60, -52, -36, -28, -56], 1),
    ([-110, 6, -90, -12, -72, 14, -50, -4, -40, -12, -30, -6, -22, -14], 0),
    ([-104, 44, -90, 32, -76, 50, -60, 38, -48, 30, -36, 40, -22, 30], 2),
    ([-86, 76, -68, 64, -50, 80, -30, 68], 4),
  ];

  void _build() {
    // Silueta: una elipse con el borde en arcos (las circunvoluciones) y una muesca arriba, entre hemisferios.
    const n = 12, rx = 122.0, ry = 100.0;
    final pts = <Offset>[];
    for (var k = 0; k <= n; k++) {
      final a = -math.pi / 2 + k * 2 * math.pi / n, sn = math.sin(a);
      pts.add(Offset(rx * math.cos(a), ry * sn * (sn > 0 ? 0.86 : 1)));
    }
    outline = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var k = 1; k <= n; k++) {
      outline.arcToPoint(pts[k], radius: Radius.circular((pts[k] - pts[k - 1]).distance * 0.60));
    }
    outline.close();

    Path curve(List<double> p, double sign) {
      final path = Path()..moveTo(p[0] * sign, p[1]);
      for (var i = 2; i + 5 < p.length + 1; i += 6) {
        path.cubicTo(p[i] * sign, p[i + 1], p[i + 2] * sign, p[i + 3], p[i + 4] * sign, p[i + 5]);
      }
      return path;
    }

    folds = [];
    foldRegion = [];
    for (final sign in [1.0, -1.0]) {
      for (final (p, r) in _left) {
        folds.add(curve(p, sign));
        foldRegion.add(r);
      }
    }
    // La cisura central, de arriba abajo.
    folds.add(Path()
      ..moveTo(0, -94)
      ..cubicTo(-5, -68, 5, -42, 0, -14)
      ..cubicTo(-4, 14, 4, 46, 0, 84));
    foldRegion.add(4);

    // Neuronas: puntos repartidos a lo largo de cada surco. Las consecutivas quedan conectadas.
    final xs = <double>[], ys = <double>[], rs = <int>[], fold = <int>[], a = <int>[], b = <int>[];
    for (var f = 0; f < folds.length; f++) {
      for (final metric in folds[f].computeMetrics()) {
        final steps = math.max(2, (metric.length / 13).round());
        for (var k = 0; k <= steps; k++) {
          final pos = metric.getTangentForOffset(metric.length * k / steps)!.position;
          xs.add(pos.dx);
          ys.add(pos.dy);
          rs.add(foldRegion[f]);
          fold.add(f);
          if (k > 0) {
            a.add(xs.length - 2);
            b.add(xs.length - 1);
          }
        }
      }
    }
    // Puentes entre surcos: cada neurona con la más cercana de OTRO surco, si está cerca.
    final seen = <int>{};
    for (var i = 0; i < xs.length; i++) {
      var best = -1;
      var bestD = 34.0 * 34.0;
      for (var j = 0; j < xs.length; j++) {
        if (fold[j] == fold[i]) continue;
        final d = (xs[i] - xs[j]) * (xs[i] - xs[j]) + (ys[i] - ys[j]) * (ys[i] - ys[j]);
        if (d < bestD) {
          bestD = d;
          best = j;
        }
      }
      if (best >= 0 && seen.add(i < best ? i * 4096 + best : best * 4096 + i)) {
        a.add(i);
        b.add(best);
      }
    }
    count = xs.length;
    x = Float32List.fromList(xs);
    y = Float32List.fromList(ys);
    region = Uint8List.fromList(rs);
    edgeA = Uint16List.fromList(a);
    edgeB = Uint16List.fromList(b);
    edgesOf = List.generate(count, (_) => <int>[]);
    for (var e = 0; e < a.length; e++) {
      edgesOf[a[e]].add(e);
      edgesOf[b[e]].add(e);
    }
  }
}

/// Las señales que viajan por el cerebro. Cada una recorre una conexión y, al llegar a la neurona,
/// la enciende un instante y sigue por otra conexión de esa misma neurona: así se ven «caminos».
class BrainSignals {
  BrainSignals({this.count = 16, int seed = 7}) : _rand = math.Random(seed) {
    final m = BrainModel.instance;
    glow = Float32List(m.count);
    for (var i = 0; i < count; i++) {
      final e = _rand.nextInt(m.edgeA.length);
      _edge.add(e);
      _forward.add(_rand.nextBool());
      _t.add(_rand.nextDouble());
      _speed.add(3.2 + _rand.nextDouble() * 3.0); // conexiones cortas: unas 3–6 por segundo
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
    _paintBrain(canvas, const Offset(200, 180), 66);
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

  /// El cerebro dentro de la cúpula: silueta que brilla, surcos de colores por región, neuronas y señales.
  /// [c] es el centro y [r] el medio ancho que debe ocupar.
  void _paintBrain(Canvas canvas, Offset c, double r) {
    final m = BrainModel.instance;
    final k = r / BrainModel.halfWidth;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(k);

    final onCount = (m.count * lit).round();
    bool on(int i) => i < onCount; // prueba: el orden hace de «umbral» (en la app será el progreso de cada región)
    const off = Color(0xFF46527A);

    // Silueta: relleno tenue y un borde que brilla, para que se lea «cerebro» de un vistazo.
    canvas.drawPath(m.outline, Paint()..shader = ui.Gradient.radial(const Offset(-20, -30), 150, [const Color(0xFF3B4FB8), const Color(0xFF182259)]));
    canvas.drawPath(
      m.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = const Color(0xFFB9CBFF).withValues(alpha: 0.16),
    );
    canvas.drawPath(
      m.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFD6E0FF).withValues(alpha: 0.92),
    );

    // Surcos: cada uno del color de su región (apagados en gris si aún no se aprendió esa parte).
    final foldPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.5;
    for (var f = 0; f < m.folds.length; f++) {
      final lightUp = lit >= 1 || f / m.folds.length < lit;
      foldPaint.color = (lightUp ? brainRegionColors[m.foldRegion[f]] : off).withValues(alpha: lightUp ? 0.62 : 0.55);
      canvas.drawPath(m.folds[f], foldPaint);
    }
    // Puentes entre surcos: líneas finas, casi invisibles; por ahí también pasan señales.
    final bridge = Paint()
      ..color = const Color(0xFFB9CBFF).withValues(alpha: 0.14)
      ..strokeWidth = 1.2;
    for (var e = 0; e < m.edgeA.length; e++) {
      if (m.region[m.edgeA[e]] != m.region[m.edgeB[e]] || (m.x[m.edgeA[e]] - m.x[m.edgeB[e]]).abs() > 16) {
        canvas.drawLine(Offset(m.x[m.edgeA[e]], m.y[m.edgeA[e]]), Offset(m.x[m.edgeB[e]], m.y[m.edgeB[e]]), bridge);
      }
    }
    // Neuronas sobre los surcos.
    final dot = Paint();
    for (var i = 0; i < m.count; i++) {
      final p = Offset(m.x[i], m.y[i]);
      if (!on(i)) {
        dot.color = off;
        canvas.drawCircle(p, 2.6, dot);
        continue;
      }
      final lightUp = signals?.glow[i] ?? 0;
      final base = brainRegionColors[m.region[i]];
      if (lightUp > 0) canvas.drawCircle(p, 4 + 7 * lightUp, Paint()..color = base.withValues(alpha: 0.35 * lightUp));
      dot.color = Color.lerp(Color.lerp(base, Colors.white, 0.25)!, Colors.white, 0.75 * lightUp)!;
      canvas.drawCircle(p, 3.1 + 1.6 * lightUp, dot);
    }
    // Señales: una cabeza brillante con su estela, viajando de neurona en neurona.
    final sig = signals;
    if (sig != null) {
      final trail = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.2;
      final head = Paint()..color = Colors.white;
      final halo = Paint()..color = const Color(0xFFFFE45C).withValues(alpha: 0.40);
      for (var i = 0; i < sig.length; i++) {
        final e = sig.edge(i);
        final ia = sig.forward(i) ? m.edgeA[e] : m.edgeB[e], ib = sig.forward(i) ? m.edgeB[e] : m.edgeA[e];
        if (!on(ia) || !on(ib)) continue; // por lo apagado no viaja nada
        final from = Offset(m.x[ia], m.y[ia]), to = Offset(m.x[ib], m.y[ib]);
        final p = Offset.lerp(from, to, sig.t(i))!, tail = Offset.lerp(from, to, math.max(0, sig.t(i) - 0.7))!;
        if ((p - tail).distance > 0.5) {
          trail.shader = ui.Gradient.linear(tail, p, [const Color(0x00FFE45C), const Color(0xF2FFF3B0)]);
          canvas.drawLine(tail, p, trail);
        }
        canvas.drawCircle(p, 8, halo);
        canvas.drawCircle(p, 3.6, head);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrainyCharacterPainter old) => true;
}
