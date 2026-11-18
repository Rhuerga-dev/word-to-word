import 'dart:math' as math;

import '../data/pet.dart';

/// Una neurona del cerebro de Brainy, en coordenadas de -1 a 1.
class Neuron {
  const Neuron(this.x, this.y, this.region, this.order, this.phase);
  final double x, y;
  final PetRegion region;

  /// 0–1: cuándo se enciende dentro de su zona (las del centro primero, así el saber «se extiende»).
  final double order;

  /// 0–1: desfase de su parpadeo, para que no latan todas a la vez.
  final double phase;

  bool lit(double level) => level > 0 && order <= level;
}

/// El cerebro de lado, hecho de neuronas: el mismo dibujo del icono de Brainy
/// (~/Code/brain/assets/icon.py), aquí en Dart. Sale igual siempre (azar con semilla).
class PetBrain {
  PetBrain._(this.neurons, this.links);

  final List<Neuron> neurons;

  /// Parejas de neuronas vecinas (índices en [neurons]).
  final List<(int, int)> links;

  static final PetBrain instance = _build();

  static const _step = 0.128; // distancia entre neuronas

  static double _ellipse(double x, double y, double cx, double cy, double rx, double ry, [double turn = 0]) {
    final c = math.cos(turn), s = math.sin(turn), dx = x - cx, dy = y - cy;
    final u = dx * c + dy * s, v = -dx * s + dy * c;
    return (u / rx) * (u / rx) + (v / ry) * (v / ry);
  }

  static bool _cortex(double x, double y) =>
      math.min(_ellipse(x, y, -0.06, -0.10, 0.74, 0.50), math.min(_ellipse(x, y, -0.30, 0.10, 0.42, 0.34, 0.25), _ellipse(x, y, 0.36, -0.02, 0.40, 0.40))) <= 1;
  static bool _cerebellum(double x, double y) => _ellipse(x, y, 0.40, 0.44, 0.27, 0.17, -0.2) <= 1;
  static bool _stem(double x, double y) => _ellipse(x, y, 0.10, 0.56, 0.085, 0.22, -0.25) <= 1 && y > 0.3;

  /// ¿A qué zona pertenece el punto? (null = fuera del cerebro)
  static PetRegion? regionAt(double x, double y) {
    if (!_cortex(x, y)) return (_cerebellum(x, y) || _stem(x, y)) ? PetRegion.links : null;
    final groove = 0.12 - 0.22 * (x + 0.45); // la línea que separa la zona del lenguaje
    if (x > -0.50 && x < 0.30 && y > groove) return PetRegion.words;
    if (x < -0.22) return PetRegion.habit;
    if (x > 0.38) return PetRegion.memory;
    return PetRegion.path;
  }

  static PetBrain _build() {
    final rnd = math.Random(7);
    final points = <(double, double, PetRegion)>[];
    var row = 0;
    for (var y = -0.75; y < 0.85; y += _step * 0.866, row++) {
      for (var x = -0.95 + (row.isOdd ? _step / 2 : 0); x < 0.95; x += _step) {
        final px = x + (rnd.nextDouble() - 0.5) * 0.044, py = y + (rnd.nextDouble() - 0.5) * 0.044;
        final region = regionAt(px, py);
        if (region != null) points.add((px, py, region));
      }
    }

    // El orden de encendido: dentro de cada zona, de la más cercana a su centro a la más lejana.
    final order = List<double>.filled(points.length, 0);
    for (final region in PetRegion.values) {
      final mine = [for (var i = 0; i < points.length; i++) if (points[i].$3 == region) i];
      if (mine.isEmpty) continue;
      final cx = mine.fold<double>(0, (s, i) => s + points[i].$1) / mine.length;
      final cy = mine.fold<double>(0, (s, i) => s + points[i].$2) / mine.length;
      double far(int i) => math.sqrt(math.pow(points[i].$1 - cx, 2) + math.pow(points[i].$2 - cy, 2));
      mine.sort((a, b) => far(a).compareTo(far(b)));
      for (var n = 0; n < mine.length; n++) {
        order[mine[n]] = (n + 1) / mine.length;
      }
    }

    final neurons = [for (var i = 0; i < points.length; i++) Neuron(points[i].$1, points[i].$2, points[i].$3, order[i], rnd.nextDouble())];
    final links = <(int, int)>[];
    const reach = _step * 1.25;
    for (var i = 0; i < neurons.length; i++) {
      for (var j = i + 1; j < neurons.length; j++) {
        final dx = neurons[i].x - neurons[j].x, dy = neurons[i].y - neurons[j].y;
        if (dx * dx + dy * dy < reach * reach) links.add((i, j));
      }
    }
    return PetBrain._(neurons, links);
  }

  /// Cuántas neuronas están encendidas con ese estado.
  int litCount(PetState p) => neurons.where((n) => n.lit(p.level(n.region))).length;
}
