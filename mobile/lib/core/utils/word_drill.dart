import 'compare.dart';

/// Una palabra que Azure calificó al decir una frase: su nota (0–100), el tipo de error y los sonidos flojos.
class WeakWord {
  const WeakWord(this.word, {this.accuracy = 0, this.error = 'None', this.phonemes = const []});
  final String word;
  final int accuracy;
  final String error;
  final List<String> phonemes;
}

/// El mini-taller de una palabra: la palabra sola, el trozo de frase donde va y sus sonidos flojos.
class DrillPlan {
  const DrillPlan({required this.word, required this.chunk, required this.sentence, this.phonemes = const []});
  final String word, chunk, sentence;
  final List<String> phonemes;

  /// El sonido más flojo (para medir ese sonido al decir la palabra sola).
  String? get phoneme => phonemes.isEmpty ? null : phonemes.first;
}

/// Por debajo de esta nota la palabra se practica aparte.
const drillMaxAccuracy = 60;

/// Desde esta nota la palabra (o el trozo) sale bien y se sigue.
const drillPassScore = 70;

/// Intentos por paso (palabra sola y trozo): después se sigue igual, sin atascarse.
const drillTries = 2;

List<String> _tokens(String t) =>
    t.replaceAll('’', "'").replaceAll(RegExp(r"[^A-Za-z0-9'\s]"), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

String _key(String w) => w.toLowerCase().replaceAll("'", '');

/// Elige UNA palabra para practicar (la peor), solo si de verdad salió mal:
/// nota muy baja (< 60) **y** además no se entendió (se oyó otra palabra o faltó).
/// Así un acento que Azure puntúa bajo, pero que se entiende, no interrumpe.
DrillPlan? pickDrill(List<WeakWord> weak, String sentence, String heard) {
  final words = _tokens(sentence);
  if (words.length < 2) return null; // una palabra suelta ya es el propio ejercicio
  final missed = {for (final (w, ok) in matchWords(sentence, heard).tokens) if (!ok) w};
  final candidates = weak.where((w) {
    final k = _key(w.word);
    if (k.isEmpty || RegExp(r'[0-9]').hasMatch(k) || !words.any((t) => _key(t) == k)) return false;
    if (w.accuracy >= drillMaxAccuracy) return false;
    return missed.contains(k) || w.error == 'Omission';
  }).toList()
    ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
  if (candidates.isEmpty) return null;
  final w = candidates.first;
  final word = words.firstWhere((t) => _key(t) == _key(w.word));
  return DrillPlan(word: word, chunk: chunkFor(sentence, word), sentence: sentence, phonemes: w.phonemes);
}

/// El trozo de frase con la palabra: ella y la siguiente (o la anterior si es la última).
/// Las palabras muy cortas (a, the, to…) se juntan con una más para que el trozo tenga sentido.
String chunkFor(String sentence, String word) {
  final words = _tokens(sentence);
  final i = words.indexWhere((t) => _key(t) == _key(word));
  if (i < 0 || words.length < 2) return word;
  var from = i, to = i;
  if (i + 1 < words.length) {
    to = i + 1;
    if (words[to].length <= 3 && to + 1 < words.length) to++;
  } else {
    from = i - 1;
    if (words[from].length <= 3 && from > 0) from--;
  }
  final chunk = words.sublist(from, to + 1).join(' ');
  // El evaluador solo acepta letras: con números ("30 years"), la palabra sola.
  return RegExp(r'[0-9]').hasMatch(chunk) ? word : chunk;
}
