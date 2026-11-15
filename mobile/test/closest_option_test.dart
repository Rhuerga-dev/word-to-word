import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/utils/compare.dart';

/// «¿Qué palabra oíste?»: si lo que se entendió se parece a una opción, la app dice cómo pronunciarla.
void main() {
  test('distancia de edición', () {
    expect(editDistance('peach', 'peach'), 0);
    expect(editDistance('beach', 'peach'), 1);
    expect(editDistance('pitch', 'peach'), 2);
    expect(editDistance('', 'abc'), 3);
  });

  test('beach se parece a peach', () {
    expect(closestOption('beach', ['pear', 'peach', 'cherry']), 1);
    expect(closestOption('I said Beach!', ['pear', 'peach', 'cherry']), 1);
  });

  test('las palabras largas aceptan 2 letras distintas', () {
    expect(closestOption('sequens', ['sequence', 'volunteer']), 0);
    expect(closestOption('sequins', ['sequence', 'volunteer']), -1);   // 3 letras: demasiado distinta
  });

  test('si no se parece a ninguna, -1', () {
    expect(closestOption('banana', ['pear', 'peach', 'cherry']), -1);
    expect(closestOption('', ['pear']), -1);
  });

  test('elige la más parecida', () {
    expect(closestOption('pea', ['pear', 'peach']), 0);
  });
}
