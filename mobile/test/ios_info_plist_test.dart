import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lo que Apple pide en el Info.plist del iPhone: si falta, la app se cierra al usar el micrófono
/// o App Store Connect pregunta por el cifrado en cada subida.
void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  /// El valor que va justo después de <key>name</key> (texto o <true/>/<false/>).
  String? valueOf(String name) {
    final m = RegExp('<key>$name</key>\\s*(<string>([^<]*)</string>|<(true|false)/>)').firstMatch(plist);
    return m == null ? null : (m.group(2) ?? m.group(3));
  }

  test('explica para qué usa el micrófono', () {
    expect(valueOf('NSMicrophoneUsageDescription'), isNotNull);
    expect(valueOf('NSMicrophoneUsageDescription')!.trim(), isNotEmpty);
  });

  test('declara que no usa cifrado especial', () {
    expect(valueOf('ITSAppUsesNonExemptEncryption'), 'false');
  });

  test('el nombre que se ve en el iPhone es W2W', () {
    expect(valueOf('CFBundleDisplayName'), 'W2W');
  });
}
