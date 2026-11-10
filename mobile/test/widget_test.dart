import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/api.dart';
import 'package:word_to_word/screens/session_screen.dart';
import 'package:word_to_word/theme.dart';

void main() {
  test('plainExample quita asteriscos o deja un hueco', () {
    expect(plainExample('I *think* so'), 'I think so');
    expect(plainExample('I *think* so', cloze: true), 'I _____ so');
    expect(plainExample(null), '');
  });

  test('days', () {
    expect(days(1), 'mañana');
    expect(days(3), 'en 3 días');
  });

  test('soundKey normaliza fonemas', () {
    expect(soundKey('r'), 'ɹ');
    expect(soundKey('iː'), 'i');
    expect(soundKey('ɝ'), 'ɜ');
    expect(soundKey('k'), isNull);
  });

  test('errorMessage toma el primer error de validación', () {
    expect(Api.errorMessage({'message': 'x', 'errors': {'email': ['Correo inválido']}}, 422), 'Correo inválido');
  });

  test('SessionPlan.fromToday ordena los pasos', () {
    final plan = SessionPlan.fromToday({
      'plan': {
        'reviews': [{'id': 1, 'word': 'a'}],
        'new': [{'id': 2, 'word': 'b'}],
        'sounds': [{'phoneme': 'θ'}],
        'mistakes': [{'id': 9}],
      }
    });
    expect(plan.steps.map((s) => s.runtimeType.toString()).toList(),
        ['ReviewStep', 'NewStep', 'SoundStep', 'SoundStep', 'NarrateStep', 'MistakeStep']);
  });
}
