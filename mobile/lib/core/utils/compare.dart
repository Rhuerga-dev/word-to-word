/// Compara lo que había que decir con lo que se entendió: qué palabras salieron bien y el porcentaje.
class WordMatch {
  const WordMatch(this.tokens, this.pct);

  /// Cada palabra del objetivo y si se dijo.
  final List<(String word, bool ok)> tokens;
  final int pct;
}

List<String> _words(String t) =>
    t.toLowerCase().replaceAll('’', "'").replaceAll("'", '').replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

WordMatch matchWords(String target, String heard) {
  final pool = _words(heard);
  final toks = <(String, bool)>[];
  for (final w in _words(target)) {
    final i = pool.indexOf(w);
    if (i >= 0) pool.removeAt(i);
    toks.add((w, i >= 0));
  }
  final ok = toks.where((t) => t.$2).length;
  return WordMatch(toks, toks.isEmpty ? 0 : (ok * 100 / toks.length).round());
}
