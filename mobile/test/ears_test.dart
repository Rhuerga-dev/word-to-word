import 'package:flutter_test/flutter_test.dart';
import 'package:word_to_word/core/services/airpods_service.dart';

void main() {
  test('AirPods: estado de las orejas desde el aviso Bluetooth', () {
    final e = EarState.fromMap({'left': true, 'right': false, 'status': 0x22, 'rssi': -40});
    expect(e.inEar, isTrue);
    expect(e.status, 0x22);
    expect(EarState.fromMap({'left': false, 'right': false}).inEar, isFalse);
    expect(EarState.fromMap(<String, dynamic>{}).inEar, isFalse); // datos raros: fuera, sin romperse
  });
}
