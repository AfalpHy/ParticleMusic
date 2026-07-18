import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/audio_handler.dart';
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

  test('远程相对音量固定调整百分之二并限制范围', () {
    expect(
      adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.raise),
      closeTo(0.52, 0.000001),
    );
    expect(
      adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.lower),
      closeTo(0.48, 0.000001),
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
      adjustedRemoteVolume(0.99, audio_service.AndroidVolumeDirection.raise),
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

    expect(next, closeTo(0.05, 0.000001));
    expect(next - 0.03, closeTo(0.02, 0.000001));
  });

  test('USB 独占激活时手机按键转换为音量方向', () {
    expect(
      usbExclusiveVolumeKeyDirection(delta: 1, active: true),
      audio_service.AndroidVolumeDirection.raise,
    );
    expect(
      usbExclusiveVolumeKeyDirection(delta: -1, active: true),
      audio_service.AndroidVolumeDirection.lower,
    );
    expect(usbExclusiveVolumeKeyDirection(delta: 0, active: true), isNull);
    expect(usbExclusiveVolumeKeyDirection(delta: 1, active: false), isNull);
  });

  test('连续手机音量键基于最新绝对音量计算目标', () {
    var target = 0.5;
    target = adjustedRemoteVolume(
      target,
      audio_service.AndroidVolumeDirection.raise,
    );
    target = adjustedRemoteVolume(
      target,
      audio_service.AndroidVolumeDirection.raise,
    );
    target = adjustedRemoteVolume(
      target,
      audio_service.AndroidVolumeDirection.lower,
    );

    expect(target, closeTo(0.52, 0.000001));
  });

  test('非独占输出固定使用满幅用户增益并交给系统音量控制', () {
    expect(outputUserVolume(active: false, requested: 0.07), 1);
    expect(outputUserVolume(active: false, requested: 0.8), 1);
    expect(outputUserVolume(active: true, requested: 0.17), 0.17);
  });
}
