import '../../../core/utils/json.dart';

enum UnitState { done, open, locked }

/// Una unidad del Camino: palabras, sonido, shadowing y la prueba de conversación.
class PathUnit {
  const PathUnit({
    required this.id,
    required this.number,
    required this.title,
    required this.state,
    required this.wordsLearned,
    required this.wordsNeed,
    required this.preview,
    required this.sound,
    required this.scenarioTitle,
    required this.steps,
    this.testScore,
    this.testFeedback,
  });

  final String id;
  final int number;
  final String title;
  final UnitState state;
  final int wordsLearned, wordsNeed;
  final List<String> preview;
  final String sound;
  final String scenarioTitle;

  /// words · sound · shadow · test → hecho
  final Map<String, bool> steps;
  final int? testScore;
  final String? testFeedback;

  static const stepOrder = ['words', 'sound', 'shadow', 'test'];
  int get stepsDone => stepOrder.where((k) => steps[k] == true).length;
  String get nextStep => stepOrder.firstWhere((k) => steps[k] != true, orElse: () => 'test');

  factory PathUnit.fromJson(Map<String, dynamic> j) {
    final words = asMap(j['words']), test = asMap(j['test']), steps = asMap(j['steps']);
    return PathUnit(
      id: asString(j['id']),
      number: asInt(j['number']),
      title: asString(j['title']),
      state: switch (j['state']) { 'done' => UnitState.done, 'open' => UnitState.open, _ => UnitState.locked },
      wordsLearned: asInt(words['learned']),
      wordsNeed: asInt(words['need']),
      preview: [for (final w in (words['preview'] as List? ?? const [])) '$w'],
      sound: asString(j['sound']),
      scenarioTitle: asString(j['scenario_title']),
      steps: {for (final k in stepOrder) k: asBool(steps[k])},
      testScore: test['score'] == null ? null : asInt(test['score']),
      testFeedback: asStringOrNull(test['feedback']),
    );
  }
}

/// El Camino del nivel (GET /path).
class PathData {
  const PathData({required this.level, required this.levelName, required this.units, required this.currentId, required this.completed});
  final String level;
  final String levelName;
  final List<PathUnit> units;
  final String? currentId;
  final int completed;

  PathUnit? get current => units.where((u) => u.id == currentId).firstOrNull;

  factory PathData.fromJson(Map<String, dynamic> j) => PathData(
        level: asString(j['level']),
        levelName: asString(j['level_name']),
        units: listOf(j['units'], PathUnit.fromJson),
        currentId: asStringOrNull(j['current']),
        completed: asInt(j['completed']),
      );
}
