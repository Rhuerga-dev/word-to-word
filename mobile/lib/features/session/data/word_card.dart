import '../../../core/utils/json.dart';

/// Una ficha de vocabulario (repaso o palabra nueva).
class WordCard {
  const WordCard({
    required this.id,
    required this.word,
    required this.translation,
    this.example,
    this.exampleEs,
    this.definition,
    this.englishOnly = false,
    this.hideTranslation = false,
    this.noSpanish = false,
    this.aid,
    this.fails = 0,
    this.level = 0,
    this.isNew = false,
    this.previews = const {},
  });

  final int id;
  final String word;
  final String translation;
  final String? example;
  final String? exampleEs;
  final String? definition;

  /// Fichas maduras: se muestran solo en inglés (definición y hueco), sin traducir.
  final bool englishOnly;

  /// Escalera de español: la traducción no se muestra de entrada (2–3) o no se muestra nunca (4).
  final bool hideTranslation;
  final bool noSpanish;

  /// Tu escena AID (Acción Irracional Detallada) para recordarla; [fails] veces seguidas olvidada.
  final String? aid;
  final int fails, level;
  final bool isNew;

  /// Días hasta el próximo repaso según la nota: again, hard, good, easy.
  final Map<String, int> previews;

  factory WordCard.fromJson(Map<String, dynamic> j) => WordCard(
        id: asInt(j['id']),
        word: asString(j['word']),
        translation: asString(j['translation']),
        example: asStringOrNull(j['example']),
        exampleEs: asStringOrNull(j['example_es']),
        definition: asStringOrNull(j['definition']),
        englishOnly: asBool(j['english_only']),
        hideTranslation: asBool(j['hide_translation']),
        noSpanish: asBool(j['no_spanish']),
        aid: asStringOrNull(j['aid']),
        fails: asInt(j['fails']),
        level: asInt(j['level']),
        isNew: j['mode'] == 'new',
        previews: {for (final e in asMap(j['previews']).entries) e.key: asInt(e.value)},
      );
}

/// Un error de tus conversaciones para decirlo bien.
class Mistake {
  const Mistake({required this.id, required this.said, required this.correct, this.why});
  final int id;
  final String said;
  final String correct;
  final String? why;

  factory Mistake.fromJson(Map<String, dynamic> j) =>
      Mistake(id: asInt(j['id']), said: asString(j['said']), correct: asString(j['correct']), why: asStringOrNull(j['why']));
}

/// Un logro (nuevo o de la lista).
class Achievement {
  const Achievement({required this.title, required this.desc, this.unlocked = false});
  final String title;
  final String desc;
  final bool unlocked;

  factory Achievement.fromJson(Map<String, dynamic> j) =>
      Achievement(title: asString(j['title']), desc: asString(j['desc']), unlocked: j['unlocked_at'] != null);
}
