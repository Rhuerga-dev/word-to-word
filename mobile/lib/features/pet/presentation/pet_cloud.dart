import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';

/// Los colores que el alumno puede elegir para su mascota. La clave es la que guarda el servidor
/// (lista fija: PetService::COLORS). Sin elegir, es del color [neutral] con el que nace.
class BrainyColors {
  static const neutral = Color(0xFFB8C0D0);
  static const choices = <(String key, String name, Color color)>[
    ('blue', 'Azul', Color(0xFF3F5BEA)),
    ('purple', 'Morado', Color(0xFF8B5CF6)),
    ('pink', 'Rosa', Color(0xFFEC5C9A)),
    ('coral', 'Coral', Color(0xFFF2694B)),
    ('orange', 'Naranja', Color(0xFFF39A2B)),
    ('green', 'Verde', Color(0xFF2FB36F)),
    ('teal', 'Turquesa', Color(0xFF17A9B8)),
  ];

  /// El color de una clave; neutro si es null o desconocida (p. ej. un color nuevo de un servidor más moderno).
  static Color of(String? key) {
    for (final (k, _, c) in choices) {
      if (k == key) return c;
    }
    return neutral;
  }

  static String nameOf(String? key) {
    for (final (k, n, _) in choices) {
      if (k == key) return tr(n);
    }
    return tr('Neutro');
  }
}

/// El cerebro de Brainy: una nube de neuronas en 3D vista desde un ángulo fijo (la misma receta del cerebro
/// del panel de Huerga Labs, con menos neuronas para el teléfono), con sus conexiones. Se construye una vez.
/// Es la misma receta del panel (public/js/brain.js en huergalabs-admin), con menos neuronas para el teléfono.
class BrainCloud {
  BrainCloud._(this.count) {
    _build();
  }

  static final BrainCloud instance = BrainCloud._(680);

  final int count;
  late final Float32List sx, sy, depth; // posición en pantalla (−1…1) y profundidad (0 = lejos, 1 = cerca)
  late final Uint8List region; // 0…4
  late final Uint16List edgeA, edgeB;
  late final List<List<int>> edgesOf; // conexiones que tocan cada neurona

  /// Todas las conexiones como pares de puntos (x1, y1, x2, y2…), listas para dibujarse de una vez.
  late final Float32List lines;

  /// Capa de profundidad de cada neurona: 0 = fondo, 1 = medio, 2 = frente.
  late final Uint8List band;

  /// Umbral de cada neurona (0–1): se enciende cuando el nivel de su región lo supera. Así, al crecer el
  /// nivel, las neuronas de esa región se van encendiendo una a una, siempre en el mismo orden.
  late final Float32List threshold;

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
    threshold = Float32List(n);
    for (var i = 0; i < n; i++) {
      threshold[i] = rand();
    }
    edgeA = Uint16List.fromList(a);
    edgeB = Uint16List.fromList(b);
    edgesOf = List.generate(n, (_) => <int>[]);
    for (var e = 0; e < a.length; e++) {
      edgesOf[a[e]].add(e);
      edgesOf[b[e]].add(e);
    }
    lines = Float32List(a.length * 4);
    for (var e = 0; e < a.length; e++) {
      lines[e * 4] = sx[a[e]];
      lines[e * 4 + 1] = sy[a[e]];
      lines[e * 4 + 2] = sx[b[e]];
      lines[e * 4 + 3] = sy[b[e]];
    }
    band = Uint8List(n);
    for (var i = 0; i < n; i++) {
      band[i] = depth[i] < 0.34 ? 0 : (depth[i] < 0.67 ? 1 : 2);
    }
  }
}

/// Las señales que viajan por el cerebro. Cada una recorre una conexión y, al llegar a la neurona,
/// la enciende un instante y sigue por otra conexión de esa misma neurona: así se ven «caminos».
class BrainSignals {
  BrainSignals({this.count = 30, int seed = 7, this.minSpeed = 1.1, this.maxSpeed = 2.6}) : _rand = math.Random(seed) {
    final m = BrainCloud.instance;
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
    final m = BrainCloud.instance;
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
