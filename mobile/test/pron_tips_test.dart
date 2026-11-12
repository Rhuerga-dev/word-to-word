import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/utils/pron_tips.dart';

void main() {
  test('técnicas: por los sonidos de Azure, sin repetir y como mucho 2 palabras', () {
    final t = buildTips([
      ('think', ['θ', 'ŋ', 'ɪ']),
      ('three', ['θ', 'iː']),
      ('very', ['v']),
    ]);
    expect(t.map((w) => w.word), ['think', 'three']);
    expect(t[0].tips.map((x) => x.phoneme), ['θ', 'ŋ']); // máximo 2 por palabra
    expect(t[1].tips.map((x) => x.phoneme), ['i']); // θ ya salió; "iː" usa la de "i"
  });

  test('sin detalle de sonidos: pistas por la ortografía', () {
    final t = buildTips([('the', const []), ('very', const [])]);
    expect(t[0].tips.first.phoneme, 'ð');
    expect(t[1].tips.first.phoneme, 'v');
    expect(buildTips([('a', const [])]), isEmpty);
  });
}
