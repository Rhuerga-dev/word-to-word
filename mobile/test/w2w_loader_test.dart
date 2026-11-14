import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_to_word/core/theme/app_theme.dart';
import 'package:word_to_word/core/widgets/async_view.dart';
import 'package:word_to_word/core/widgets/w2w_loader.dart';

import 'support/test_fonts.dart';

/// Altos de las barras que se ven ahora mismo.
List<double> heights(WidgetTester t) => t
    .widgetList<Container>(find.descendant(of: find.byKey(const ValueKey('w2w-loader')), matching: find.byType(Container)))
    .map((c) => c.constraints!.maxHeight)
    .toList();

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await useTestFonts();
  });

  testWidgets('las barras se mueven, con texto debajo', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: W2WLoader(label: 'Cargando…')))));
    final a = heights(t);
    expect(a, hasLength(5));
    await t.pump(const Duration(milliseconds: 300));
    expect(heights(t), isNot(equals(a)));
    expect(find.text('Cargando…'), findsOneWidget);
    expect(find.bySemanticsLabel('Cargando…'), findsOneWidget);
  });

  testWidgets('pequeño: 3 barras y sin texto', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: W2WLoader.small()))));
    expect(heights(t), hasLength(3));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('si el teléfono pide menos movimiento, quedan quietas', (t) async {
    await t.pumpWidget(const MaterialApp(home: MediaQuery(data: MediaQueryData(disableAnimations: true), child: Scaffold(body: W2WLoader()))));
    final a = heights(t);
    await t.pump(const Duration(milliseconds: 400));
    expect(heights(t), equals(a));
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('AsyncView usa el cargando de W2W', (t) async {
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: AsyncView<int>(value: const AsyncLoading(), data: (_) => const SizedBox()))),
    ));
    expect(find.byType(W2WLoader), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // Imagen para mirar cómo queda: flutter test test/w2w_loader_test.dart --dart-define=PREVIEW=ruta.png
  const preview = String.fromEnvironment('PREVIEW');
  testWidgets('vista previa', (t) async {
    t.view.physicalSize = const Size(1080, 1200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      theme: W.theme(),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          backgroundColor: W.callBg,
          body: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            const SizedBox(height: 180, child: W2WLoadingScreen()),
            const W2WLoader(label: 'Cargando…'),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Cómo decirla  '), const W2WLoader.small()]),
            Container(color: W.navy, padding: const EdgeInsets.all(16), child: const W2WLoader(color: Colors.white)),
          ]),
        ),
      ),
    ));
    // Que terminen de cargar las fuentes antes de la foto.
    for (var i = 0; i < 5; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 60));
    }
    await t.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 3);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(preview).writeAsBytesSync(png!.buffer.asUint8List());
    });
  }, skip: preview.isEmpty);
}
