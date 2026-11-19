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

/// Lo que necesitan las señales para viajar: neuronas y conexiones entre ellas.
abstract class BrainGraph {
  int get count;
  Uint16List get edgeA;
  Uint16List get edgeB;
  List<List<int>> get edgesOf;
}

/// El cerebro que se ve dentro de la cúpula: una silueta con sus surcos bien marcados (visto de frente, con
/// los dos hemisferios). Cada surco pertenece a una región y lleva sus neuronas; las neuronas vecinas están
/// conectadas, también de un surco a otro, para que las señales puedan recorrer todo el cerebro.
/// Coordenadas en una hoja propia: centro (0, 0), ancho ≈ 244, alto ≈ 200. Se construye una sola vez.
class BrainModel implements BrainGraph {
  BrainModel._() {
    _build();
  }

  static final BrainModel instance = BrainModel._();

  /// Medio ancho y medio alto de la silueta (para encajarla donde haga falta).
  static const halfWidth = 136.0, halfHeight = 112.0;

  late final Path outline; // la silueta, con sus «bultos»
  late final List<Path> folds; // los surcos
  late final List<int> foldRegion; // región (0…4) de cada surco
  @override
  late final int count; // neuronas
  late final Float32List x, y;
  late final Uint8List region;
  @override
  late final Uint16List edgeA;
  @override
  late final Uint16List edgeB;
  @override
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

/// El cerebro 3D del panel de Huerga Labs (public/js/brain.js en huergalabs-admin), portado tal cual:
/// la misma semilla, la misma forma (corteza con surcos, lóbulos temporales, cerebelo y tronco), el mismo
/// ángulo de vista y las mismas tres capas de profundidad. Aquí no gira: la vista se calcula una sola vez.
/// Lleva menos neuronas que el panel (el teléfono lo dibuja en un espacio mucho más pequeño).
class Brain3D implements BrainGraph {
  Brain3D._(this.count, {this.yaw = -0.95, this.pitch = 0.22}) {
    _build();
  }

  /// La vista del panel al abrirse (de tres cuartos).
  static final Brain3D instance = Brain3D._(1500);

  /// Visto DE FRENTE, un poco desde arriba: los dos hemisferios con la cisura en medio.
  /// Es el que hace de cabeza del personaje.
  static final Brain3D front = Brain3D._(1700, yaw: 0, pitch: 0.16);

  /// Giro horizontal e inclinación de la vista.
  final double yaw, pitch;

  @override
  final int count;
  late final Float32List sx, sy, scale; // posición en pantalla (unidades del cerebro) y tamaño por cercanía

  /// Las coordenadas 3D sin girar (x = izquierda/derecha, y = arriba, z = delante): para dibujarlo girando.
  late final Float32List x3, y3, z3;
  late final Uint8List region, band; // región 0…4; capa 0 = fondo, 1 = medio, 2 = frente
  @override
  late final Uint16List edgeA;
  @override
  late final Uint16List edgeB;
  @override
  late final List<List<int>> edgesOf;
  late final Uint8List edgeRegion;

  /// Para dibujar deprisa: los índices de las neuronas de cada (región, capa) y las conexiones de cada región.
  late final List<List<Float32List>> pointsByRegionBand;
  late final List<Float32List> linesByRegion;

  static int _imul(int a, int b) {
    // Multiplicación de 32 bits como Math.imul de JavaScript (sin perder precisión).
    final al = a & 0xFFFF, ah = (a >>> 16) & 0xFFFF;
    return ((al * (b & 0xFFFFFFFF)) + (((ah * (b & 0xFFFFFFFF)) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }

  /// Azar con semilla, idéntico al del panel: el cerebro sale igual.
  static double Function() _seeded(int seed) {
    var s = seed & 0xFFFFFFFF;
    return () {
      s = (s + 0x6D2B79F5) & 0xFFFFFFFF;
      var t = _imul(s ^ (s >>> 15), 1 | s);
      t = ((t + _imul(t ^ (t >>> 7), 61 | t)) & 0xFFFFFFFF) ^ t;
      return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
    };
  }

  void _build() {
    final rand = _seeded(20261117);
    final xs = <double>[], ys = <double>[], zs = <double>[], ph = <int>[];
    void add(double x, double y, double z, int p) {
      xs.add(x);
      ys.add(y);
      zs.add(z);
      ph.add(p);
    }

    List<double> direction() {
      final u = rand() * 2 - 1, a = rand() * math.pi * 2, s = math.sqrt(1 - u * u);
      return [s * math.cos(a), u, s * math.sin(a)];
    }

    double groove(double x, double y, double z) {
      final n = math.sin(11 * x + 3 * math.sin(4 * z)) + math.sin(9 * z + 2.5 * math.sin(5 * y)) + math.sin(10 * y + 2 * math.sin(6 * x));
      return math.exp(-math.pow(n / 0.35, 2).toDouble());
    }

    // Ejes: x = izquierda/derecha, y = arriba, z = delante (+) / atrás (−).
    while (xs.length < count * 0.74) {
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
      if (y < 0) y *= 0.72; // base más plana
      x *= 1 - 0.13 * z; // más estrecho delante
      final ax = x.abs();
      if (y > -0.1) y -= 0.16 * math.exp(-math.pow(ax / 0.1, 2).toDouble()); // la cisura hunde el centro
      x = (x < 0 ? -1 : 1) * (ax * 0.93 + 0.045); // y separa los hemisferios
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
      add(x, y, z, p);
    }
    while (xs.length < count * 0.83) {
      final d = direction();
      final r = 0.85 + 0.15 * rand(), side = rand() < 0.5 ? -1 : 1;
      add(side * 0.5 + d[0] * 0.17 * r, -0.3 + d[1] * 0.15 * r, 0.12 + d[2] * 0.42 * r, 2);
    }
    while (xs.length < count * 0.96) {
      final d = direction();
      final r = rand() < 0.25 ? 0.4 + 0.5 * rand() : 0.94 + 0.06 * rand();
      final y = (d[1] * 0.2 * r * 26).round() / 26; // láminas del cerebelo
      add(d[0] * 0.46 * r, -0.5 + y, -0.6 + d[2] * 0.27 * r, 4);
    }
    while (xs.length < count) {
      final t = rand(), a = rand() * math.pi * 2, r = (0.1 - 0.035 * t) * math.sqrt(rand());
      add(math.cos(a) * r, -0.42 - 0.56 * t, -0.28 - 0.12 * t + math.sin(a) * r, 4);
    }

    x3 = Float32List.fromList(xs);
    y3 = Float32List.fromList(ys);
    z3 = Float32List.fromList(zs);

    // La vista del panel al abrirse: giro −0,95, inclinación 0,22. Lo cercano, más grande.
    const dist = 3.4;
    final cy = math.cos(yaw), syw = math.sin(yaw), cp = math.cos(pitch), sp = math.sin(pitch);
    final n = xs.length;
    sx = Float32List(n);
    sy = Float32List(n);
    scale = Float32List(n);
    region = Uint8List.fromList(ph);
    band = Uint8List(n);
    for (var i = 0; i < n; i++) {
      final x = xs[i], y = ys[i] + 0.14, z = zs[i];
      final x1 = x * cy + z * syw, z1 = -x * syw + z * cy;
      final y2 = y * cp - z1 * sp, z2 = y * sp + z1 * cp;
      final k = dist / (dist - z2);
      sx[i] = x1 * k;
      sy[i] = -y2 * k;
      scale[i] = k;
      band[i] = z2 < -0.3 ? 0 : (z2 < 0.3 ? 1 : 2);
    }

    // Conexiones: cada neurona con sus 2 vecinas más cercanas (en 3D), como en el panel.
    final a = <int>[], b = <int>[], er = <int>[];
    final seen = <int>{};
    for (var i = 0; i < n; i++) {
      var b1 = -1, b2 = -1;
      var d1 = double.infinity, d2 = double.infinity;
      for (var j = 0; j < n; j++) {
        if (j == i) continue;
        final dx = xs[i] - xs[j], dy = ys[i] - ys[j], dz = zs[i] - zs[j];
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
        if (seen.add(i < j ? i * n + j : j * n + i)) {
          a.add(i);
          b.add(j);
          er.add(ph[i]);
        }
      }
    }
    edgeA = Uint16List.fromList(a);
    edgeB = Uint16List.fromList(b);
    edgeRegion = Uint8List.fromList(er);
    edgesOf = List.generate(n, (_) => <int>[]);
    for (var e = 0; e < a.length; e++) {
      edgesOf[a[e]].add(e);
      edgesOf[b[e]].add(e);
    }

    pointsByRegionBand = List.generate(5, (p) {
      return List.generate(3, (bd) {
        final out = <double>[];
        for (var i = 0; i < n; i++) {
          if (ph[i] == p && band[i] == bd) out..add(sx[i])..add(sy[i]);
        }
        return Float32List.fromList(out);
      });
    });
    linesByRegion = List.generate(5, (p) {
      final out = <double>[];
      for (var e = 0; e < a.length; e++) {
        if (er[e] == p) out..add(sx[a[e]])..add(sy[a[e]])..add(sx[b[e]])..add(sy[b[e]]);
      }
      return Float32List.fromList(out);
    });
  }
}

/// Las señales que viajan por el cerebro. Cada una recorre una conexión y, al llegar a la neurona,
/// la enciende un instante y sigue por otra conexión de esa misma neurona: así se ven «caminos».
class BrainSignals {
  BrainSignals({this.count = 16, int seed = 7, BrainGraph? graph, this.minSpeed = 3.2, this.maxSpeed = 6.2})
      : graph = graph ?? BrainModel.instance,
        _rand = math.Random(seed) {
    final m = this.graph;
    glow = Float32List(m.count);
    for (var i = 0; i < count; i++) {
      final e = _rand.nextInt(m.edgeA.length);
      _edge.add(e);
      _forward.add(_rand.nextBool());
      _t.add(_rand.nextDouble());
      _speed.add(minSpeed + _rand.nextDouble() * (maxSpeed - minSpeed)); // conexiones por segundo
    }
  }

  final int count;

  /// El cerebro por el que viajan.
  final BrainGraph graph;
  final double minSpeed, maxSpeed;
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
    final m = graph;
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
  BrainyCharacterPainter({required this.color, this.pose = BrainyPose.main, this.lit = 1, this.signals, this.blink = 0, this.brain3d = false, this.headBrain = false, super.repaint});

  /// true = el cerebro 3D del panel dentro de la cúpula; false = el cerebro dibujado con surcos.
  final bool brain3d;

  /// true = el cerebro ES la cabeza: el cuerpo llega hasta encima de los ojos y, de ahí para arriba, el cerebro 3D
  /// visto de frente dentro de un cráneo de cristal. (Las señales deben viajar por [Brain3D.front].)
  final bool headBrain;

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

    if (!headBrain) {
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
    }

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

    final faceDy = headBrain ? -14.0 : 0.0; // en la versión «cerebro = cabeza» la cara sube un poco
    if (headBrain) {
      // La cabeza ES el cerebro: su contorno son los dos hemisferios (dos lóbulos redondos con la muesca en medio),
      // como un cráneo de cristal que el cerebro llena entero. Va DETRÁS del cuerpo: el cuerpo tapa la mitad de
      // abajo y el borde queda justo encima de los ojos.
      final skull = Path.combine(
        PathOperation.union,
        Path()..addOval(Rect.fromCenter(center: const Offset(150, 228), width: 146, height: 212)),
        Path()..addOval(Rect.fromCenter(center: const Offset(250, 228), width: 146, height: 212)),
      );
      canvas.drawPath(skull, Paint()..shader = ui.Gradient.radial(const Offset(200, 200), 150, [const Color(0xFF1E2B6A), const Color(0xFF080D2A)]));
      canvas.save();
      canvas.clipPath(skull);
      _paintBrain3D(canvas, const Offset(200, 240), 150, Brain3D.front);
      canvas.restore();
      canvas.drawPath(
        skull,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round
          ..color = _shade(color, 0.34).withValues(alpha: 0.9),
      );
      final shine = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(90, 206)
          ..cubicTo(92, 172, 108, 146, 134, 136),
        shine,
      );
      canvas.drawCircle(const Offset(147, 132), 3, Paint()..color = Colors.white.withValues(alpha: 0.5));

      // Cuerpo: empieza justo encima de los ojos.
      final body = RRect.fromLTRBAndCorners(84, 232, 316, 378,
          topLeft: const Radius.circular(34), topRight: const Radius.circular(34), bottomLeft: const Radius.elliptical(114, 112), bottomRight: const Radius.elliptical(114, 112));
      canvas.drawRRect(body, Paint()..shader = ui.Gradient.linear(const Offset(200, 232), const Offset(200, 380), [light, color, dark], const [0, 0.4, 1]));
      // El borde donde el cráneo se apoya en el cuerpo.
      canvas.drawLine(
        const Offset(102, 236),
        const Offset(298, 236),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(200, 322), width: 160, height: 100),
        Paint()..shader = ui.Gradient.radial(const Offset(200, 322), 80, [Colors.white.withValues(alpha: 0.26), Colors.white.withValues(alpha: 0)]),
      );
    } else {
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
      if (brain3d) {
        // Ampliado para llenar la cúpula de lado a lado: el tronco y parte del borde quedan fuera, recortados por el cristal.
        _paintBrain3D(canvas, const Offset(203, 188), 93);
      } else {
        _paintBrain(canvas, const Offset(200, 180), 66);
      }
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
    }

    // Cara.
    canvas.save();
    canvas.translate(0, faceDy);
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
    canvas.restore(); // faceDy
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

  /// El cerebro 3D del panel, dibujado igual que allí: conexiones tenues por región, cada neurona con un halo
  /// suave y un centro vivo, más apagado cuanto más al fondo, y las luces se SUMAN donde se juntan.
  /// [r] = cuántas unidades de la hoja mide «1» del cerebro (su medio largo).
  void _paintBrain3D(Canvas canvas, Offset c, double r, [Brain3D? model]) {
    final m = model ?? Brain3D.instance;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(r);
    final unit = 1 / r; // 1 unidad de la hoja, en unidades del cerebro
    // Más suave que en el panel: aquí el cerebro es mucho más pequeño y las luces se amontonan (se quemaría en blanco).
    const halo = [0.035, 0.055, 0.08], core = [0.34, 0.55, 0.85];
    final lines = Paint()
      ..strokeWidth = 0.45 * unit
      ..blendMode = BlendMode.plus;
    final dots = Paint()
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    for (var p = 0; p < 5; p++) {
      final base = brainRegionColors[p];
      lines.color = base.withValues(alpha: r > 120 ? 0.26 : 0.16);
      canvas.drawRawPoints(ui.PointMode.lines, m.linesByRegion[p], lines);
      for (var b = 0; b < 3; b++) {
        final pts = m.pointsByRegionBand[p][b];
        // Lo cercano, un poco más grande. Cuanto más ampliado va el cerebro, más gruesa cada neurona (si no, queda ralo).
        final size = (0.62 + 0.10 * b) * unit * math.max(1.0, r / 92);
        dots
          ..color = base.withValues(alpha: halo[b])
          ..strokeWidth = size * 2.6 * 2;
        canvas.drawRawPoints(ui.PointMode.points, pts, dots);
        dots
          ..color = base.withValues(alpha: core[b])
          ..strokeWidth = size * 1.25 * 2;
        canvas.drawRawPoints(ui.PointMode.points, pts, dots);
      }
    }
    // Señales que viajan por las conexiones y encienden la neurona a la que llegan.
    final sig = signals;
    if (sig != null && identical(sig.graph, m)) {
      final flash = Paint()..blendMode = BlendMode.plus;
      for (var i = 0; i < m.count; i++) {
        final g = sig.glow[i];
        if (g <= 0.02) continue;
        flash.color = Colors.white.withValues(alpha: 0.45 * g);
        canvas.drawCircle(Offset(m.sx[i], m.sy[i]), (0.9 + 1.1 * g) * unit, flash);
      }
      final trail = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.9 * unit;
      final head = Paint()..color = Colors.white;
      final glow = Paint()
        ..color = const Color(0xFFFFE45C).withValues(alpha: 0.45)
        ..blendMode = BlendMode.plus;
      for (var i = 0; i < sig.length; i++) {
        final e = sig.edge(i);
        final ia = sig.forward(i) ? m.edgeA[e] : m.edgeB[e], ib = sig.forward(i) ? m.edgeB[e] : m.edgeA[e];
        final from = Offset(m.sx[ia], m.sy[ia]), to = Offset(m.sx[ib], m.sy[ib]);
        final p = Offset.lerp(from, to, sig.t(i))!, tail = Offset.lerp(from, to, math.max(0, sig.t(i) - 0.8))!;
        if ((p - tail).distance > 0.2 * unit) {
          trail.shader = ui.Gradient.linear(tail, p, [const Color(0x00FFE45C), const Color(0xF2FFF3B0)]);
          canvas.drawLine(tail, p, trail);
        }
        canvas.drawCircle(p, 1.9 * unit, glow);
        canvas.drawCircle(p, 0.85 * unit, head);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrainyCharacterPainter old) => true;
}


/// Los surcos del cerebro colocados sobre la cabeza, en 3D: cada surco es una línea ondulada dibujada sobre
/// una esfera, dada por (longitud, latitud). Longitud 0 = el frente; +π/2 = un lado; π = la espalda.
/// Los dos hemisferios son espejo uno del otro, y entre ellos va la cisura central, de delante a atrás por arriba.
class BrainFolds {
  BrainFolds._() {
    // Hemisferio derecho: surcos que van del frente a la espalda pasando por el lado, a distintas alturas.
    const bands = <(double lat, double amp, double freq, double phase, double from, double to)>[
      (0.20, 0.085, 3.0, 0.0, 0.16, 2.98),
      (0.46, 0.090, 2.6, 1.3, 0.20, 2.94),
      (0.72, 0.085, 2.2, 2.4, 0.26, 2.88),
      (0.98, 0.070, 1.8, 0.7, 0.36, 2.78),
      (1.22, 0.050, 1.2, 1.9, 0.60, 2.54),
    ];
    for (final side in [1.0, -1.0]) {
      for (final (lat, amp, freq, phase, from, to) in bands) {
        final line = <(double, double)>[];
        const steps = 44;
        for (var k = 0; k <= steps; k++) {
          final t = k / steps;
          line.add((side * (from + (to - from) * t), lat + amp * math.sin(freq * t * 2 * math.pi + phase)));
        }
        lines.add(line);
      }
      // Ramitas cortas entre surcos, para que no parezcan rayas paralelas.
      for (final (lon, lat0, lat1) in const [(0.55, 0.26, 0.40), (1.25, 0.52, 0.66), (2.0, 0.26, 0.40), (0.9, 0.78, 0.92), (1.9, 0.78, 0.92), (2.55, 0.52, 0.66)]) {
        lines.add([for (var k = 0; k <= 6; k++) (side * (lon + 0.05 * math.sin(k * 1.1)), lat0 + (lat1 - lat0) * k / 6)]);
      }
    }
    // La cisura central: sube por el frente, pasa por arriba y baja por la espalda.
    final fissure = <(double, double)>[];
    for (var k = 0; k <= 30; k++) {
      fissure.add((0.0, 0.06 + (math.pi / 2 - 0.06) * k / 30));
    }
    for (var k = 1; k <= 30; k++) {
      fissure.add((math.pi, math.pi / 2 - (math.pi / 2 - 0.06) * k / 30));
    }
    fissureIndex = lines.length;
    lines.add(fissure);
  }

  static final BrainFolds instance = BrainFolds._();

  final lines = <List<(double, double)>>[];
  late final int fissureIndex;
}

/// Señales que viajan por los surcos: cada una recorre un surco de punta a punta y luego salta a otro.
class FoldSignals {
  FoldSignals({int count = 9, int seed = 5}) : _rand = math.Random(seed) {
    final n = BrainFolds.instance.lines.length;
    for (var i = 0; i < count; i++) {
      fold.add(_rand.nextInt(n));
      t.add(_rand.nextDouble());
      _speed.add(0.22 + _rand.nextDouble() * 0.25);
      _dir.add(_rand.nextBool() ? 1 : -1);
    }
  }

  final math.Random _rand;
  final fold = <int>[], t = <double>[], _speed = <double>[], _dir = <int>[];

  void step(double dt) {
    final n = BrainFolds.instance.lines.length;
    for (var i = 0; i < fold.length; i++) {
      t[i] += dt * _speed[i] * _dir[i];
      if (t[i] > 1 || t[i] < 0) {
        fold[i] = _rand.nextInt(n);
        _dir[i] = _rand.nextBool() ? 1 : -1;
        t[i] = _dir[i] > 0 ? 0 : 1;
      }
    }
  }
}

/// Las dos piezas del personaje.
enum BrainyPart { doll, brain, both }

/// PRUEBA: el personaje como objeto 3D que se puede girar los 360° y se ve coherente desde cualquier lado.
///
/// Cómo se consigue sin un motor 3D:
/// - El cuerpo y la cúpula son formas REDONDAS alrededor del eje vertical: su contorno es el mismo se miren
///   desde donde se miren, así que basta dibujar el mismo contorno.
/// - Lo que sí cambia al girar se coloca en 3D y se proyecta en cada cuadro: los ojos, las mejillas y la boca
///   se desplazan por la superficie, se estrechan al acercarse al borde y desaparecen por detrás; los brazos y
///   los pies dan la vuelta y pasan por delante o por detrás del cuerpo; y el cerebro (puntos 3D de verdad)
///   gira dentro de la cúpula.
/// [yaw] = giro en radianes (0 = de frente).
class Brainy3DPainter extends CustomPainter {
  Brainy3DPainter({required this.color, this.yaw = 0, this.signals, this.blink = 0, this.foldSignals, this.solidBrain = true, this.part = BrainyPart.both});

  /// Qué se dibuja: el mono solo, el cerebro solo, o los dos unidos. Son dos piezas independientes.
  final BrainyPart part;

  /// true = la cabeza es un cerebro SÓLIDO con surcos (se reconoce a cualquier tamaño y sobre cualquier fondo);
  /// false = el cerebro de puntos de luz del panel.
  final bool solidBrain;

  /// Las luces que recorren los surcos (solo con [solidBrain]).
  final FoldSignals? foldSignals;

  final Color color;
  final double yaw;
  final BrainSignals? signals;
  final double blink;

  static const _cx = 200.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 400, size.height / 420);
    canvas.save();
    canvas.translate((size.width - 400 * s) / 2, (size.height - 420 * s) / 2);
    canvas.scale(s);
    switch (part) {
      case BrainyPart.doll:
        _paintDoll(canvas, front: false);
        _paintDoll(canvas, front: true);
      case BrainyPart.brain:
        canvas.drawOval(Rect.fromCenter(center: const Offset(_cx, 330), width: 190, height: 20), Paint()..color = const Color(0x40050A2A));
        _paintBrainPart(canvas, const Offset(_cx, 222));
      case BrainyPart.both:
        // La unión: primero lo que queda detrás del mono, luego el cerebro apoyado encima, y por último el mono
        // (su parte de arriba tapa la base del cerebro: el cerebro descansa sobre él, no va metido dentro).
        _paintDoll(canvas, front: false, onlyBack: true);
        _paintBrainPart(canvas, const Offset(_cx, 196));
        _paintDoll(canvas, front: false, skipBack: true, brainOnTop: true);
        _paintDoll(canvas, front: true);
    }
    canvas.restore();
  }

  /// PIEZA 1 · El mono: cuerpo redondo, cara, brazos y pies. Se dibuja en dos pasadas: lo de detrás y el cuerpo
  /// ([front] = false) y luego lo que queda por delante ([front] = true).
  void _paintDoll(Canvas canvas, {required bool front, bool onlyBack = false, bool skipBack = false, bool brainOnTop = false}) {
    final light = BrainyCharacterPainter._shade(color, 0.16), dark = BrainyCharacterPainter._shade(color, -0.20), darker = BrainyCharacterPainter._shade(color, -0.27);
    final cs = math.cos(yaw);
    (double, double) around(double radius, double angle) => (_cx + radius * math.sin(yaw + angle), radius * math.cos(yaw + angle));
    final limb = Paint()..shader = ui.Gradient.linear(const Offset(0, 240), const Offset(0, 330), [BrainyCharacterPainter._shade(color, 0.04), dark]);
    void foot(double angle) {
      final (x, _) = around(46, angle);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, 378), width: 60, height: 30), Paint()..color = darker);
    }

    void arm(double angle) {
      final (x, z) = around(118, angle);
      final side = (x - _cx) / 118;
      canvas.save();
      canvas.translate(x, 294);
      canvas.rotate(-side * 18 * math.pi / 180);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 38 * (0.75 + 0.25 * (z / 118).abs() + 0.25 * side.abs()).clamp(0.75, 1.0), height: 72), limb);
      canvas.restore();
    }

    const feet = [0.45, -0.45], arms = [math.pi / 2, -math.pi / 2];
    if (front) {
      for (final a in feet) {
        if (around(46, a).$2 >= 0) foot(a);
      }
      for (final a in arms) {
        if (around(118, a).$2 >= 0) arm(a);
      }
      return;
    }
    if (!skipBack) {
      canvas.drawOval(Rect.fromCenter(center: const Offset(_cx, 396), width: 200, height: 22), Paint()..color = const Color(0x59050A2A));
      for (final a in feet) {
        if (around(46, a).$2 < 0) foot(a);
      }
      for (final a in arms) {
        if (around(118, a).$2 < 0) arm(a);
      }
    }
    if (onlyBack) return;

    // El cuerpo: redondo por abajo y con «hombros» redondeados por arriba (ahí se apoya el cerebro).
    final body = RRect.fromLTRBAndCorners(84, 214, 316, 378,
        topLeft: const Radius.elliptical(96, 58), topRight: const Radius.elliptical(96, 58), bottomLeft: const Radius.elliptical(114, 112), bottomRight: const Radius.elliptical(114, 112));
    canvas.drawRRect(body, Paint()..shader = ui.Gradient.linear(const Offset(_cx, 214), const Offset(_cx, 380), [light, color, dark], const [0, 0.42, 1]));

    canvas.save();
    canvas.clipRRect(body);
    if (brainOnTop) {
      // Sombra suave que el cerebro deja sobre el mono: se nota que está apoyado encima.
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(_cx, 212), width: 236, height: 64),
        Paint()..shader = ui.Gradient.radial(const Offset(_cx, 212), 118, [const Color(0x55081040), const Color(0x00081040)], const [0.55, 1.0]),
      );
    }
    if (cs > 0) {
      final (bx, _) = around(70, 0);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bx, 326), width: 160 * (0.35 + 0.65 * cs), height: 96),
        Paint()..shader = ui.Gradient.radial(Offset(bx, 326), 80, [Colors.white.withValues(alpha: 0.26 * cs), Colors.white.withValues(alpha: 0)]),
      );
    }
    (double, double)? face(double angle) {
      final (x, z) = around(112, angle);
      final facing = z / 112;
      return facing > 0.06 ? (x, facing) : null;
    }

    final cheek = Paint()..color = const Color(0x99FF8FB1);
    for (final a in [0.60, -0.60]) {
      final f = face(a);
      if (f != null) canvas.drawOval(Rect.fromCenter(center: Offset(f.$1, 296), width: 30 * f.$2, height: 20), cheek);
    }
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    for (final a in [0.33, -0.33]) {
      final f = face(a);
      if (f == null) continue;
      final (x, w) = f;
      if (blink > 0.85) {
        canvas.drawPath(
          Path()
            ..moveTo(x - 15 * w, 274)
            ..quadraticBezierTo(x, 288, x + 15 * w, 274),
          white,
        );
        continue;
      }
      final eye = Rect.fromCenter(center: Offset(x, 274), width: 34 * w, height: 40 * (1 - blink));
      canvas.drawOval(eye, Paint()..color = Colors.white);
      canvas.save();
      canvas.clipPath(Path()..addOval(eye));
      final look = (_cx - x) * 0.05;
      canvas.drawOval(Rect.fromCenter(center: Offset(x + look, 278), width: 22 * w, height: 22), Paint()..color = const Color(0xFF0B1238));
      canvas.drawOval(Rect.fromCenter(center: Offset(x + look + 4 * w, 273), width: 8.4 * w, height: 8.4), Paint()..color = Colors.white);
      canvas.restore();
    }
    final mouth = face(0);
    if (mouth != null) {
      final (x, w) = mouth;
      canvas.drawPath(
        Path()
          ..moveTo(x - 18 * w, 304)
          ..quadraticBezierTo(x, 324, x + 18 * w, 304),
        white,
      );
    }
    canvas.restore();
  }

  /// PIEZA 2 · El cerebro, como objeto propio con centro en [c]: más ancho que alto, más largo de delante a
  /// atrás que de lado a lado (por eso su contorno cambia al girar), borde con bultos, base más plana y oscura,
  /// surcos en 3D, los dos hemisferios y las señales.
  void _paintBrainPart(Canvas canvas, Offset c) {
    const rx = 124.0, rz = 138.0, ryTop = 100.0, ryLow = 50.0, pitch = 0.20;
    final cy0 = math.cos(yaw), sy0 = math.sin(yaw), cp = math.cos(pitch), sp = math.sin(pitch);
    // Medio ancho de la silueta a este ángulo.
    final w = math.sqrt(rx * rx * cy0 * cy0 + rz * rz * sy0 * sy0);
    final surface = BrainyCharacterPainter._shade(color, 0.26, -0.06), surfaceDark = BrainyCharacterPainter._shade(color, 0.07);
    final groove = BrainyCharacterPainter._shade(color, -0.14, 0.04), under = BrainyCharacterPainter._shade(color, -0.10);

    // Contorno: por arriba, una fila de bultos (las circunvoluciones del borde); por abajo, la base, más plana.
    const bumps = 8;
    final outline = Path()..moveTo(c.dx - w, c.dy);
    var prev = Offset(c.dx - w, c.dy);
    for (var k = 1; k <= bumps; k++) {
      final a = math.pi - k * math.pi / bumps;
      final p = Offset(c.dx + w * math.cos(a), c.dy - ryTop * math.sin(a));
      outline.arcToPoint(p, radius: Radius.circular((p - prev).distance * 0.62));
      prev = p;
    }
    outline
      ..arcToPoint(Offset(c.dx - w, c.dy), radius: Radius.elliptical(w, ryLow))
      ..close();

    canvas.save();
    canvas.clipPath(outline);
    canvas.drawRect(Rect.fromLTRB(c.dx - w - 20, c.dy - ryTop - 30, c.dx + w + 20, c.dy + ryLow + 10),
        Paint()..shader = ui.Gradient.radial(Offset(c.dx - 40, c.dy - 50), 190, [surface, surfaceDark]));
    // La base, en sombra.
    canvas.drawRect(Rect.fromLTRB(c.dx - w - 20, c.dy + 4, c.dx + w + 20, c.dy + ryLow + 10),
        Paint()..shader = ui.Gradient.linear(Offset(c.dx, c.dy + 4), Offset(c.dx, c.dy + ryLow), [under.withValues(alpha: 0), under.withValues(alpha: 0.85)]));

    (Offset, double) project(double lon, double lat) {
      final cl = math.cos(lat);
      final x = rx * cl * math.sin(lon), y = ryTop * math.sin(lat), z = rz * cl * math.cos(lon);
      final x1 = x * cy0 + z * sy0, z1 = -x * sy0 + z * cy0;
      final y2 = y * cp - z1 * sp * 0.55, depth = (y / ryTop) * sp + (z1 / rz) * cp;
      return (Offset(c.dx + x1, c.dy - y2), depth);
    }

    final folds = BrainFolds.instance;
    for (var f = 0; f < folds.lines.length; f++) {
      final line = folds.lines[f];
      final thick = f == folds.fissureIndex ? 9.0 : 6.5;
      // Cada tramo visible del surco es un trazo seguido (así sale liso, no dentado).
      Path? path, glint;
      var widthSum = 0.0, count = 0;
      void flush() {
        if (path == null || count == 0) return;
        final facing = widthSum / count;
        canvas.drawPath(
          path!,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = groove.withValues(alpha: 0.6 + 0.3 * facing)
            ..strokeWidth = thick * (0.4 + 0.6 * facing),
        );
        canvas.drawPath(
          glint!,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white.withValues(alpha: 0.30)
            ..strokeWidth = 2.2 * (0.4 + 0.6 * facing),
        );
        path = null;
        glint = null;
        widthSum = 0;
        count = 0;
      }

      for (var k = 0; k < line.length; k++) {
        final (p, z) = project(line[k].$1, line[k].$2);
        if (z <= 0.05) {
          flush();
          continue;
        }
        final lift = thick * 0.62 * z.clamp(0.0, 1.0);
        if (path == null) {
          path = Path()..moveTo(p.dx, p.dy);
          glint = Path()..moveTo(p.dx, p.dy - lift);
        } else {
          path!.lineTo(p.dx, p.dy);
          glint!.lineTo(p.dx, p.dy - lift);
        }
        widthSum += z.clamp(0.0, 1.0);
        count++;
      }
      flush();
    }

    final sig = foldSignals;
    if (sig != null) {
      final glow = Paint()..color = const Color(0xFFFFE45C).withValues(alpha: 0.45);
      final head = Paint()..color = Colors.white;
      final trail = Paint()..strokeCap = StrokeCap.round;
      for (var i = 0; i < sig.fold.length; i++) {
        final line = folds.lines[sig.fold[i]];
        (Offset, double) at(double t) {
          final pos = t.clamp(0.0, 1.0) * (line.length - 1), k = pos.floor().clamp(0, line.length - 2), u = pos - k;
          return project(line[k].$1 + (line[k + 1].$1 - line[k].$1) * u, line[k].$2 + (line[k + 1].$2 - line[k].$2) * u);
        }

        final (p, z) = at(sig.t[i]);
        if (z < 0.08) continue;
        for (var j = 5; j >= 1; j--) {
          final (a, za) = at(sig.t[i] - j * 0.012);
          final (b, zb) = at(sig.t[i] - (j - 1) * 0.012);
          if (za < 0.08 || zb < 0.08) continue;
          trail
            ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.85 * (1 - j / 6))
            ..strokeWidth = 4.2 * z.clamp(0.0, 1.0);
          canvas.drawLine(a, b, trail);
        }
        canvas.drawCircle(p, 8.5 * z.clamp(0.0, 1.0), glow);
        canvas.drawCircle(p, 3.6 * z.clamp(0.0, 1.0), head);
      }
    }
    canvas.restore();
    // Un borde fino del tono del surco, para que el contorno con bultos se lea bien sobre cualquier fondo.
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = groove.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(Brainy3DPainter old) => true;
}
