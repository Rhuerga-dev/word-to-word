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

/// Cuántas letras hay que cambiar, quitar o poner para pasar de [a] a [b] (distancia de edición).
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// La opción que más se parece a lo que se entendió ("beach" → "peach"), o -1 si ninguna se parece.
/// Se mira cada palabra de lo oído: "I said beach" también vale. Parecida = como mucho 1 letra distinta
/// en palabras cortas, 2 en las de 7 letras o más.
int closestOption(String heard, List<String> options) {
  final words = heard.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  var best = -1;
  var bestD = 1 << 30;
  for (var i = 0; i < options.length; i++) {
    final o = options[i].toLowerCase().trim();
    final allowed = o.length >= 7 ? 2 : 1;
    for (final w in words) {
      final d = editDistance(w, o);
      if (d <= allowed && d < bestD) {
        best = i;
        bestD = d;
      }
    }
  }
  return best;
}
