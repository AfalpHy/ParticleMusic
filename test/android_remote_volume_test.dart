import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

void main() {
  UsbExclusivePlaybackState state({
    required bool active,
    bool hardware = false,
    bool digital = false,
    int? bitDepth = 24,
  }) => UsbExclusivePlaybackState.fromMap({
    'active': active,
    'hardwareVolumeActive': hardware,
    'digitalVolumeActive': digital,
    'bitDepth': bitDepth,
  });

  test('远程音量仅用于正在处理音量的 USB 独占播放', () {
    expect(
      shouldUseRemoteAndroidVolume(state(active: true, hardware: true)),
      isTrue,
    );
    expect(
      shouldUseRemoteAndroidVolume(state(active: true, digital: true)),
      isTrue,
    );
    expect(
      shouldUseRemoteAndroidVolume(state(active: false, hardware: true)),
      isFalse,
    );
    expect(shouldUseRemoteAndroidVolume(state(active: true)), isFalse);
    expect(
      shouldUseRemoteAndroidVolume(
        state(active: true, digital: true, bitDepth: 1),
      ),
      isFalse,
    );
  });

  test('远程相对音量按固定步长调整并限制范围', () {
    expect(
      adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.raise),
      0.52,
    );
    expect(
      adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.lower),
      0.48,
    );
    expect(
      adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.same),
      0.5,
    );
    expect(
      adjustedRemoteVolume(0.99, audio_service.AndroidVolumeDirection.raise),
      1,
    );
    expect(
      adjustedRemoteVolume(0.01, audio_service.AndroidVolumeDirection.lower),
      0,
    );
  });

  test('远程绝对音量将系统索引映射到 0 到 1', () {
    expect(absoluteRemoteVolume(0), 0);
    expect(absoluteRemoteVolume(50), 0.5);
    expect(absoluteRemoteVolume(100), 1);
    expect(absoluteRemoteVolume(-1), 0);
    expect(absoluteRemoteVolume(101), 1);
  });
}
