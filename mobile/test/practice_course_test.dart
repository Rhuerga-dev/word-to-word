// Practicar: lo que un curso no tiene (taller de sonidos del inglés, narración) no se ofrece.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/features/practice/data/practice_repository.dart';
import 'package:word_to_word/features/practice/presentation/practice_page.dart';
import 'package:word_to_word/features/practice/presentation/practice_providers.dart';
import 'package:word_to_word/features/today/data/today.dart';
import 'package:word_to_word/features/today/presentation/today_providers.dart';

import 'support/test_fonts.dart';

TodayData _today(List<String>? steps) => TodayData.fromJson({
      'xp': {'xp': 0, 'goal': 100},
      'plan': {'reviews': <Object>[], 'new': <Object>[], 'sounds': <Object>[], 'mistakes': <Object>[], if (steps != null) 'steps': steps},
    });

Future<void> _open(WidgetTester tester, List<String>? steps) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      practiceProvider.overrideWith((ref) async => const PracticeData(mistakes: [], cards: [])),
      todayProvider.overrideWith((ref) async => _today(steps)),
    ],
    child: const MaterialApp(home: Scaffold(body: PracticePage())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(useTestFonts);

  testWidgets('curso de inglés (o servidor viejo): narración y pronunciación, como siempre', (tester) async {
    await _open(tester, null);
    expect(find.text('Narración'), findsOneWidget);
    expect(find.text('Pronunciación'), findsOneWidget);
    expect(find.text('Repetir como un nativo'), findsNothing);
  });

  testWidgets('curso de español: sin «think» ni narración; se ofrece repetir frases', (tester) async {
    await _open(tester, ['ear', 'reviews', 'new', 'shadowing', 'mistakes']);
    expect(find.text('Pronunciación'), findsNothing);
    expect(find.textContaining('think'), findsNothing);
    expect(find.text('Narración'), findsNothing);
    expect(find.text('Repetir como un nativo'), findsOneWidget);
    expect(find.text('Fichas'), findsOneWidget);
  });
}
