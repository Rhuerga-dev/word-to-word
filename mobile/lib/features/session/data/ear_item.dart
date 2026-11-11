import '../../../core/utils/json.dart';

/// Escalones del Oído, de menos a más difícil.
const earSteps = ['sound', 'easy', 'repeat_word', 'repeat_phrase', 'repeat_sentence', 'repeat_long'];

/// Lo que suena: un texto y si va despacio.
class EarAudio {
  const EarAudio(this.text, {this.slow = false});
  final String text;
  final bool slow;
}

/// Oído: una palabra que ya aprendiste para reconocerla al oírla.
/// Primero se escucha y se toca: sound (la palabra escrita que oíste) · easy (su significado fácil).
/// Después se escucha y se REPITE, cada vez algo más largo: repeat_word · repeat_phrase · repeat_sentence · repeat_long.
class EarItem {
  const EarItem({
    required this.id,
    required this.word,
    this.mode = 'easy',
    this.audio = const [],
    this.example,
    this.options = const [],
    this.answer = 0,
    this.level = 0,
    this.fastMs = 3000,
    this.target,
    this.meaning2,
    this.pass = 80,
  });
  final int id;
  final String word;
  final String mode;
  final List<EarAudio> audio;
  final String? example;
  final List<String> options;
  final int answer;
  final int level;
  final int fastMs;

  /// Lo que hay que repetir (escalones de repetir) y su significado fácil.
  final String? target;
  final String? meaning2;

  /// % de palabras que hay que decir bien para pasar.
  final int pass;

  bool get isRepeat => mode.startsWith('repeat_');

  String get meaning => isRepeat ? (meaning2 ?? '') : options[answer];

  /// 1–6, para la barra de escalones.
  int get step => earSteps.indexOf(mode) + 1;

  /// Las opciones son definiciones (se pueden tocar sus palabras para entenderlas).
  bool get definitions => false;

  List<EarAudio> get sounds => audio.isEmpty ? [EarAudio(word)] : audio;

  factory EarItem.fromJson(Map<String, dynamic> j) => EarItem(
        id: asInt(j['id']),
        word: asString(j['word']),
        mode: asString(j['mode'], 'easy'),
        audio: [for (final a in asMaps(j['audio'])) EarAudio(asString(a['text']), slow: asBool(a['slow']))],
        example: asStringOrNull(j['example']),
        options: [for (final o in (j['options'] as List? ?? const [])) '$o'],
        answer: asInt(j['answer']),
        level: asInt(j['ear_level']),
        fastMs: asInt(j['fast_ms'], 3000),
        target: asStringOrNull(j['target']),
        meaning2: asStringOrNull(j['meaning']),
        pass: asInt(j['pass'], 80),
      );
}

/// Lo que respondió el servidor: si fue rápido, si ya es automática, el escalón nuevo y los puntos.
class EarResult {
  const EarResult({this.xp = 0, this.fast = false, this.automatic = false, this.mode});
  final int xp;
  final bool fast, automatic;
  final String? mode;
}

/// El significado simple de una palabra que no entiendes (al tocarla).
class WordLookup {
  const WordLookup({required this.word, this.emoji, this.gloss, this.easy});
  final String word;
  final String? emoji, gloss, easy;

  String get text => [if (emoji != null) emoji!, gloss ?? easy ?? ''].join(' ').trim();

  factory WordLookup.fromJson(Map<String, dynamic> j) =>
      WordLookup(word: asString(j['word']), emoji: asStringOrNull(j['emoji']), gloss: asStringOrNull(j['gloss']), easy: asStringOrNull(j['easy']));
}
