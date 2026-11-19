// El texto de «cuándo vuelve la palabra» bajo cada botón de la ficha.
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/utils/format.dart';

void main() {
  test('una palabra olvidada vuelve hoy; el resto, mañana o en N días', () {
    expect(days(0), 'hoy otra vez');
    expect(days(1), 'mañana');
    expect(days(3), 'en 3 días');
  });
}
