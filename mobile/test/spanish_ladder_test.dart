import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/l10n/tr.dart';
import 'package:word_to_word/core/services/audio_service.dart';
import 'package:word_to_word/core/utils/compare.dart';
import 'package:word_to_word/features/session/data/ear_item.dart';
import 'package:word_to_word/features/today/data/today.dart';
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

  test('voz baja: no se da por silencio si hubo algo por encima del ruido', () {
    final empty = Uint8List(0);
    expect(Recording(empty, false, 1000, peakDb: -42, floorDb: -60).maybeVoice, isTrue);
    expect(Recording(empty, false, 1000, peakDb: -57, floorDb: -60).maybeVoice, isFalse); // solo ruido
    expect(Recording(empty, false, 1000, peakDb: -70, floorDb: -72).maybeVoice, isFalse);
    expect(Recording(empty, true, 1000, peakDb: -20, floorDb: -60).maybeVoice, isFalse); // ya se oyó
  });

  test('oído: el plan de hoy empieza por las palabras para reconocer al oírlas', () {
    final d = TodayData.fromJson({
      'xp': {'xp': 0, 'goal': 100},
      'plan': {
        'ear': [
          {'id': 7, 'word': 'invoice', 'options': ['a', 'b', 'c'], 'answer': 2, 'ear_level': 1},
        ],
        'reviews': [], 'new': [], 'sounds': [], 'mistakes': [], 'speak': 'narrate',
      },
    });
    expect(d.ear.single.word, 'invoice');
    expect(d.ear.single.meaning, 'c');
    expect(EarItem.fromJson({'id': 1, 'word': 'x', 'options': ['q'], 'answer': 0}).level, 0);
  });

  test('oído: primero tocar, después repetir algo cada vez más largo', () {
    final e = EarItem.fromJson({
      'id': 3, 'word': 'rent', 'mode': 'repeat_phrase', 'fast_ms': 4000, 'pass': 80,
      'audio': [{'text': 'pay the rent', 'slow': false}], 'target': 'pay the rent', 'meaning': '🏠 money for a house',
      'options': [], 'answer': null, 'ear_level': 3,
    });
    expect(e.step, 4);
    expect(e.isRepeat, isTrue);
    expect(e.meaning, '🏠 money for a house');
    expect(e.sounds.single.text, 'pay the rent');
    final s = EarItem.fromJson({'id': 1, 'word': 'think', 'mode': 'sound', 'options': ['think', 'sink', 'thing'], 'answer': 0});
    expect(s.step, 1);
    expect(s.isRepeat, isFalse);
  });

  test('repetir: se compara palabra por palabra', () {
    final m = matchWords('Pay the rent.', 'pay de rent');
    expect(m.pct, 67);
    expect(m.tokens.map((t) => t.$2), [true, false, true]);
    expect(matchWords("I can't pay", 'I cant pay').pct, 100);
    expect(matchWords('rent', '').pct, 0);
  });
}
