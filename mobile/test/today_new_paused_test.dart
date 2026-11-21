import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/features/today/data/today.dart';
import 'package:word_to_word/features/today/presentation/today_page.dart';

Map<String, dynamic> today({bool? paused, int due = 0, int? at}) => {
      'xp': {'xp': 0, 'goal': 100, 'total': 0, 'sessions': 0, 'week': []},
      'streak': 1,
      'minutes': 0,
      'plan': {'reviews': [], 'new': [], 'sounds': [], 'speak': 'narrate', 'mistakes': []},
      if (paused != null) 'new_paused': paused,
      'reviews_due': due,
      if (at != null) 'new_pause_at': at,
    };

void main() {
  test('reads why there are no new words today', () {
    final d = TodayData.fromJson(today(paused: true, due: 49, at: 20));
    expect(d.newPaused, isTrue);
    expect(d.reviewsDue, 49);
    expect(pausedNote(d), 'Hoy no hay palabras nuevas: tienes 49 repasos atrasados. Cuando bajen de 21, vuelven las nuevas.');
  });

  test('old server (no threshold) still explains it', () {
    final d = TodayData.fromJson(today(paused: true, due: 33));
    expect(pausedNote(d), 'Hoy no hay palabras nuevas: primero ponte al día con tus 33 repasos atrasados.');
  });

  test('not paused (or older server without the field) shows nothing', () {
    expect(TodayData.fromJson(today()).newPaused, isFalse);
    expect(TodayData.fromJson(today(paused: false, due: 5)).newPaused, isFalse);
  });
}
