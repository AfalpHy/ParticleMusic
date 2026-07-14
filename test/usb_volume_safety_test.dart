import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/audio_handler.dart';

void main() {
  test('降低音量立即使用请求值', () {
    expect(nextSafeUsbVolume(0.8, 0.2), 0.2);
    expect(nextSafeUsbVolume(0.8, 0), 0);
  });

  test('提高音量单次最多增加两个百分级', () {
    expect(nextSafeUsbVolume(0.1, 0.9), closeTo(0.12, 0.000001));
    expect(nextSafeUsbVolume(0.1, 0.11), 0.11);
  });

  test('音量安全步进限制输入和输出范围', () {
    expect(nextSafeUsbVolume(-1, 2), 0.02);
    expect(nextSafeUsbVolume(0.99, 2), 1);
    expect(nextSafeUsbVolume(2, -1), 0);
  });
}
