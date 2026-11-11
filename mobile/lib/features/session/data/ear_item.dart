import '../../../core/utils/json.dart';

/// Oído: una palabra que ya aprendiste para reconocerla al oírla, con 3 significados para elegir.
class EarItem {
  const EarItem({required this.id, required this.word, this.example, required this.options, required this.answer, this.level = 0});
  final int id;
  final String word;
  final String? example;
  final List<String> options;
  final int answer;
  final int level;

  String get meaning => options[answer];

  factory EarItem.fromJson(Map<String, dynamic> j) => EarItem(
        id: asInt(j['id']),
        word: asString(j['word']),
        example: asStringOrNull(j['example']),
        options: [for (final o in (j['options'] as List? ?? const [])) '$o'],
        answer: asInt(j['answer']),
        level: asInt(j['ear_level']),
      );
}

/// Lo que respondió el servidor: si fue rápido, si ya es automática y los puntos.
class EarResult {
  const EarResult({this.xp = 0, this.fast = false, this.automatic = false});
  final int xp;
  final bool fast, automatic;
}
