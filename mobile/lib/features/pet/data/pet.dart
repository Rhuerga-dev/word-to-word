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

/// Lo que Brainy necesita. Cada cosa se cuida estudiando.
enum PetNeed {
  /// Comida: palabras nuevas y repasos.
  food,

  /// Ánimo: jugar (Oído, hablar).
  joy,

  /// Limpieza: sin repasos ni errores pendientes.
  clean,

  /// Salud: enferma si pasa un día con hambre o con mucho desorden.
  health,
}

/// Los botones de cuidado. El servidor dice qué ejercicio toca (POST /api/pet/{name}).
enum PetAction { feed, play, clean, medicine }

/// Cómo está Brainy ahora (lo calcula el servidor con el reloj: baja aunque la app esté cerrada).
class PetCare {
  const PetCare({
    this.hearts = const {},
    this.max = 4,
    this.mood = 'ok',
    this.asleep = false,
    this.hibernating = false,
    this.sick = false,
    this.mess = 0,
    this.days = 0,
    this.leaning,
    this.form,
    this.history = const [],
  });

  /// Corazones de cada barra, de 0 a [max].
  final Map<PetNeed, int> hearts;
  final int max;

  /// hibernating · asleep · sick · hungry · messy · bored · happy · ok
  final String mood;
  final bool asleep, hibernating, sick;

  /// Repasos y errores pendientes (su «desorden») y días distintos en que la cuidaste.
  final int mess, days;

  /// Hacia qué forma adulta va (talker · listener · scholar · balanced) y la que ya tiene de adulta.
  final String? leaning, form;

  /// Su evolución: (clave de etapa, fecha AAAA-MM-DD).
  final List<(String, String)> history;

  int of(PetNeed n) => hearts[n] ?? max;

  /// Duerme (de noche) o hiberna: ojos cerrados.
  bool get resting => asleep || hibernating;

  static PetCare? tryParse(Object? json) {
    if (json is! Map) return null;
    final j = asMap(json), needs = asMap(j['needs']);
    if (needs.isEmpty) return null;
    final max = asInt(asMap(needs['food'])['max'], 4).clamp(1, 10);
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    return PetCare(
      hearts: {for (final n in PetNeed.values) n: asInt(asMap(needs[n.name])['hearts'], max).clamp(0, max)},
      max: max,
      mood: asString(j['mood'], 'ok'),
      asleep: j['asleep'] == true,
      hibernating: j['hibernating'] == true,
      sick: j['sick'] == true,
      mess: asInt(j['mess']),
      days: asInt(j['days']),
      leaning: text(j['leaning']),
      form: text(j['form']),
      history: [for (final h in asMaps(j['history'])) (asString(h['stage']), asString(h['at']))],
    );
  }
}

/// El estado de la mascota (GET /api/pet). Lo calcula el servidor con lo que ya aprendiste.
class PetState {
  const PetState({
    this.name = 'Brainy',
    this.named = false,
    this.welcomed = true,
    this.points = 0,
    this.stage = 0,
    this.stageKey = 'spark',
    this.stages = 5,
    this.stageProgress = 0,
    this.nextAt,
    this.skills = const {},
    this.care,
  });

  final String name;

  /// ¿El alumno le puso nombre? (false = se llama «Brainy», el nombre de siempre.)
  final bool named;

  /// ¿Ya vio su nacimiento y respondió a «¿cómo me quieres llamar?»? Con un servidor viejo (no lo dice) vale true:
  /// así nunca se enseña la bienvenida donde no se podría guardar el nombre.
  final bool welcomed;
  final int points;

  /// Etapa actual (0 = recién nacida) de [stages] etapas.
  final int stage, stages;
  final String stageKey;

  /// Cuánto lleva de esta etapa (0–1) y los puntos que pide la siguiente (null = es la última).
  final double stageProgress;
  final int? nextAt;

  final Map<PetRegion, PetSkill> skills;

  /// Sus cuidados; null con un servidor que aún no los tiene (entonces la mascota sale como antes, sin barras).
  final PetCare? care;

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
      named: j['named'] == true,
      welcomed: j['welcomed'] != false,
      points: asInt(j['points']),
      stage: asInt(s['index']).clamp(0, count - 1),
      stageKey: asString(s['key'], 'spark'),
      stages: count,
      stageProgress: asDouble(s['progress']).clamp(0, 1).toDouble(),
      nextAt: s['next'] == null ? null : asInt(s['next']),
      skills: {for (final r in PetRegion.values) r: PetSkill.fromJson(asMap(regions[r.name]))},
      care: PetCare.tryParse(j['care']),
    );
  }
}
