import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/l10n/tr.dart';
import 'package:word_to_word/features/auth/data/user_profile.dart';
import 'package:word_to_word/features/session/data/word_card.dart';

void main() {
  tearDown(() => Lang.english = false);

  test('tr: español tal cual, inglés desde el escalón 3, con huecos', () {
    expect(tr('Hoy'), 'Hoy');
    expect(tr('Unidad {0} de {1}', [2, 6]), 'Unidad 2 de 6');
    Lang.english = true;
    expect(tr('Hoy'), 'Today');
    expect(tr('Unidad {0} de {1}', [2, 6]), 'Unit 2 of 6');
    expect(trn(1, '{0} día', '{0} días'), '1 day');
    expect(trn(3, '{0} día', '{0} días'), '3 days');
    expect(tr('Texto que no está'), 'Texto que no está');
  });

  test('tr: manda el diccionario del servidor y avisa de lo que falta', () {
    final missing = <String>[];
    Lang.english = true;
    Lang.remote = {'Hoy': 'Today!'};
    Lang.onMissing = missing.add;
    expect(tr('Hoy'), 'Today!');
    expect(tr('Camino'), 'Path'); // respaldo de la app
    expect(tr('Algo nuevo'), 'Algo nuevo');
    expect(missing, ['Algo nuevo']);
    Lang.remote = const {};
    Lang.onMissing = null;
  });

  test('perfil: la escalera de español viene en /me', () {
    final p = UserProfile.fromJson({
      'name': 'Ana',
      'spanish': {'step': 3, 'auto': false, 'base': 2, 'coach': 'en', 'limit': 5, 'today': 2, 'left': 3, 'streak': 1},
    });
    expect(p.spanish.step, 3);
    expect(p.spanish.uiEnglish, isTrue);
    expect(p.spanish.hideTranslation, isTrue);
    expect(p.spanish.noSpanish, isFalse);
    expect(p.spanish.left, 3);
    expect(p.spanish.coachVoice, 'en');
    expect(UserProfile.fromJson({'name': 'Ana'}).spanish.step, 1);
  });

  test('ficha: oculta la traducción según el escalón', () {
    final c = WordCard.fromJson({'id': 1, 'word': 'post', 'translation': 'correo', 'hide_translation': true, 'no_spanish': true});
    expect(c.hideTranslation, isTrue);
    expect(c.noSpanish, isTrue);
  });
}
