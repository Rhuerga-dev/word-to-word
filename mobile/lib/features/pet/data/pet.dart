import '../../../core/utils/json.dart';

/// Las zonas del cerebro de Brainy. Cada una se enciende con una cosa que TÚ haces en W2W.
enum PetRegion {
  /// Palabras aprendidas.
  words,

  /// Palabras que recuerdas bien (memoria FSRS).
  memory,

  /// Unidades del Camino completas.
  path,

  /// Días seguidos estudiando.
  habit,

  /// Las conexiones entre zonas: se encienden con todo lo demás.
  links,
}

/// Cuánto está encendida una zona: [count] de [target] → [level] de 0 a 1.
class PetSkill {
  const PetSkill({this.count = 0, this.target = 0, this.level = 0});
  final int count, target;
  final double level;

  factory PetSkill.fromJson(Map<String, dynamic> j) =>
      PetSkill(count: asInt(j['count']), target: asInt(j['target']), level: asDouble(j['level']).clamp(0, 1).toDouble());
}

/// El estado de la mascota (GET /api/pet). Lo calcula el servidor con lo que ya aprendiste.
class PetState {
  const PetState({
    this.name = 'Brainy',
    this.points = 0,
    this.stage = 0,
    this.stageKey = 'spark',
    this.stages = 5,
    this.stageProgress = 0,
    this.nextAt,
    this.skills = const {},
  });

  final String name;
  final int points;

  /// Etapa actual (0 = recién nacida) de [stages] etapas.
  final int stage, stages;
  final String stageKey;

  /// Cuánto lleva de esta etapa (0–1) y los puntos que pide la siguiente (null = es la última).
  final double stageProgress;
  final int? nextAt;

  final Map<PetRegion, PetSkill> skills;

  PetSkill skill(PetRegion r) => skills[r] ?? const PetSkill();
  double level(PetRegion r) => skill(r).level;
  int get pointsToNext => nextAt == null ? 0 : (nextAt! - points).clamp(0, 1 << 30);

  /// null si la respuesta no es una mascota (servidor viejo o respuesta vacía).
  static PetState? tryParse(Object? json) {
    final j = asMap(json);
    if (j['stage'] is! Map || j['regions'] is! Map) return null;
    final s = asMap(j['stage']), regions = asMap(j['regions']);
    final count = asInt(s['count'], 5).clamp(1, 12);
    return PetState(
      name: asString(j['name'], 'Brainy'),
      points: asInt(j['points']),
      stage: asInt(s['index']).clamp(0, count - 1),
      stageKey: asString(s['key'], 'spark'),
      stages: count,
      stageProgress: asDouble(s['progress']).clamp(0, 1).toDouble(),
      nextAt: s['next'] == null ? null : asInt(s['next']),
      skills: {for (final r in PetRegion.values) r: PetSkill.fromJson(asMap(regions[r.name]))},
    );
  }
}
