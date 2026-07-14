import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/replay_gain.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

void main() {
  UsbExclusivePlaybackState state({
    required bool active,
    bool hardware = false,
    bool digital = false,
    bool verified = false,
    int? bitDepth = 24,
  }) => UsbExclusivePlaybackState.fromMap({
    'active': active,
    'hardwareVolumeActive': hardware,
    'digitalVolumeActive': digital,
    'hardwareVolumeReadbackVerified': verified,
    'bitDepth': bitDepth,
  });

  test('安卓播放信息始终使用本地音量模式', () {
    final hardware = androidPlaybackInfoFor(
      state(active: true, hardware: true, verified: true),
      0.426,
    );
    final digital = androidPlaybackInfoFor(
      state(active: true, digital: true),
      -1,
    );

    expect(hardware, isA<audio_service.LocalAndroidPlaybackInfo>());
    expect(digital, isA<audio_service.LocalAndroidPlaybackInfo>());
    expect(
      androidPlaybackInfoFor(
        state(active: false, hardware: true, verified: true),
        0.5,
      ),
      isA<audio_service.LocalAndroidPlaybackInfo>(),
    );
    expect(
      androidPlaybackInfoFor(state(active: true), 0.5),
      isA<audio_service.LocalAndroidPlaybackInfo>(),
    );
    expect(
      androidPlaybackInfoFor(
        state(active: true, digital: true, bitDepth: 1),
        0.5,
      ),
      isA<audio_service.LocalAndroidPlaybackInfo>(),
    );
  });

  test('远程相对音量按分贝步长调整并限制范围', () {
    expect(
      adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.raise),
      closeTo(0.5 * dbToUsbVolumeRatio(2.5), 0.000001),
    );
    expect(
      adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.lower),
      closeTo(0.5 / dbToUsbVolumeRatio(2.5), 0.000001),
    );
    expect(
      adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.same),
      0.5,
    );
    expect(
      adjustedRemoteVolume(1, audio_service.AndroidVolumeDirection.raise),
      1,
    );
    expect(
      adjustedRemoteVolume(0.01, audio_service.AndroidVolumeDirection.lower),
      0,
    );
  });

  test('低音量区单次手机加音量不会产生十余分贝跃升', () {
    final next = adjustedRemoteVolume(
      0.03,
      audio_service.AndroidVolumeDirection.raise,
    );

    expect(next, closeTo(0.03 * dbToUsbVolumeRatio(2.5), 0.000001));
    expect(
      usbExclusiveDigitalVolumeGain(next) / usbExclusiveDigitalVolumeGain(0.03),
      closeTo(dbToLinear(2.5), 0.000001),
    );
  });
}
