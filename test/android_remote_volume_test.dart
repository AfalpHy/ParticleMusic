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

  test('安卓播放信息按 USB 实际音量路径切换远程和本地模式', () {
    final hardware = androidPlaybackInfoFor(
      state(active: true, hardware: true),
      0.426,
    );
    final digital = androidPlaybackInfoFor(
      state(active: true, digital: true),
      -1,
    );

    expect(hardware, isA<audio_service.RemoteAndroidPlaybackInfo>());
    final remote = hardware as audio_service.RemoteAndroidPlaybackInfo;
    expect(
      remote.volumeControlType,
      audio_service.AndroidVolumeControlType.absolute,
    );
    expect(remote.maxVolume, 100);
    expect(remote.volume, 43);
    expect((digital as audio_service.RemoteAndroidPlaybackInfo).volume, 0);
    expect(
      (androidPlaybackInfoFor(state(active: true, hardware: true), 2)
              as audio_service.RemoteAndroidPlaybackInfo)
          .volume,
      100,
    );
    expect(
      androidPlaybackInfoFor(state(active: false, hardware: true), 0.5),
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

  test('远程相对音量按固定步长调整并限制范围', () {
    expect(
      adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.raise),
      0.55,
    );
    expect(
      adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.lower),
      0.45,
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

  test('远程绝对音量降低立即生效而提高单次不超过百分之二十', () {
    expect(adjustedAbsoluteRemoteVolume(0.6, 20), 0.2);
    expect(adjustedAbsoluteRemoteVolume(0.2, 90), 0.4);
    expect(adjustedAbsoluteRemoteVolume(0.95, 100), 1);
  });
}
