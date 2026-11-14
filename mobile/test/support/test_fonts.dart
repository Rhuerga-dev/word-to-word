// Solo para tests: la app "ve" las fuentes de test/fonts como si fueran recursos suyos.
// Así google_fonts las encuentra sin internet y sin meterlas en pubspec (eso cambiaría lo que se instala).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nombre de la variante en test/fonts (fetch.py) → nombre que busca google_fonts.
const _variant = {
  'regular': 'Regular',
  'italic': 'Italic',
  '500': 'Medium',
  '600': 'SemiBold',
  '700': 'Bold',
  '700italic': 'BoldItalic',
  '800': 'ExtraBold',
};

/// Llamar en setUpAll, antes de dibujar la app.
Future<void> useTestFonts() async {
  final files = <String, File>{};
  for (final f in Directory('test/fonts').listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
    final name = f.uri.pathSegments.last.replaceAll('.ttf', '');
    final cut = name.lastIndexOf('_');
    final v = _variant[name.substring(cut + 1)];
    if (v != null) files['google_fonts/${name.substring(0, cut)}-$v.ttf'] = f;
  }
  final manifest = const StandardMessageCodec().encodeMessage({for (final k in files.keys) k: <Object>[]});

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (msg) async {
    final key = utf8.decode(msg!.buffer.asUint8List(msg.offsetInBytes, msg.lengthInBytes));
    if (key == 'AssetManifest.bin') return manifest;
    final f = files[key] ?? File('build/unit_test_assets/$key');
    return f.existsSync() ? ByteData.sublistView(f.readAsBytesSync()) : null;
  });

  // Iconos de Material (la fuente "MaterialIcons" del SDK de Flutter).
  final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}
