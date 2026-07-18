import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';

void main() {
  tearDown(() {
    usbAudioPreferences.resetForTest();
  });

  test('loads and serializes USB audio preferences', () {
    usbAudioPreferences.load({
      'usbFixedSampleRateEnabled': true,
      'usbFixedSampleRate': 96000,
      'usbDsdMode': 'native',
      'usbDsd64PcmRate': 176400,
      'usbPerformanceMode': false,
      'usbVolumeControlMode': 'digital',
      'usbDsdGainCompensation': -6,
      'usbBitDepthMode': 'pcm32',
      'usbReleaseBandwidthAfterPlayback': true,
      'usbKeepAliveInBackground': false,
      'usbForegroundBufferMs': 320,
      'usbBackgroundBufferMs': 2400,
      'usbVolumeSmoothHandoff': false,
    });

    expect(usbAudioPreferences.preferredFixedSampleRate(), 96000);
    expect(usbAudioPreferences.dsdModeNotifier.value, UsbDsdMode.native);
    expect(usbAudioPreferences.dsd64PcmRateNotifier.value, 176400);
    expect(usbAudioPreferences.performanceModeNotifier.value, isFalse);
    expect(
      usbAudioPreferences.volumeControlModeNotifier.value,
      UsbVolumeControlMode.digital,
    );
    expect(usbAudioPreferences.dsdGainCompensationNotifier.value, -6);
    expect(usbAudioPreferences.preferredEncoding(), 'pcm_32bit');
    expect(
      usbAudioPreferences.releaseUsbBandwidthAfterPlaybackNotifier.value,
      isTrue,
    );
    expect(usbAudioPreferences.keepAliveInBackgroundNotifier.value, isFalse);
    expect(usbAudioPreferences.foregroundBufferMsNotifier.value, 320);
    expect(usbAudioPreferences.backgroundBufferMsNotifier.value, 1000);
    expect(usbAudioPreferences.volumeSmoothHandoffNotifier.value, isFalse);
    final map = usbAudioPreferences.toMap();
    expect(map['usbDsdMode'], 'native');
    expect(map['usbForegroundBufferMs'], 320);
    expect(map['usbBackgroundBufferMs'], 1000);
    expect(map, isNot(contains('usbBusSpeedMode')));
    expect(map, isNot(contains('usbBitDepthCompat')));
    expect(map, isNot(contains('usbSampleRateCompat')));
    expect(map, isNot(contains('usbChannelCompat')));
    expect(map, isNot(contains('usbTpdfDither')));
    expect(map, isNot(contains('usbDelayedUsbLink')));
  });

  test('uses practical defaults for USB buffer and volume options', () {
    usbAudioPreferences.load(const {});

    expect(
      usbAudioPreferences.replayGainModeNotifier.value,
      ReplayGainMode.off,
    );
    expect(usbAudioPreferences.foregroundBufferMsNotifier.value, 200);
    expect(usbAudioPreferences.backgroundBufferMsNotifier.value, 1000);
    expect(usbAudioPreferences.volumeSmoothHandoffNotifier.value, isTrue);
    expect(
      usbAudioPreferences.volumeControlModeNotifier.value,
      UsbVolumeControlMode.auto,
    );
  });

  test('selects exclusive target buffer for foreground and background', () {
    usbAudioPreferences.load({
      'usbForegroundBufferMs': 320,
      'usbBackgroundBufferMs': 2400,
      'usbKeepAliveInBackground': true,
    });

    expect(preferredUsbExclusiveTargetBufferMs(background: false), 320);
    expect(preferredUsbExclusiveTargetBufferMs(background: true), 1000);

    usbAudioPreferences.keepAliveInBackgroundNotifier.value = false;
    expect(preferredUsbExclusiveTargetBufferMs(background: true), 320);
  });

  test('loads and serializes ReplayGain modes', () {
    for (final mode in ReplayGainMode.values) {
      usbAudioPreferences.load({'usbReplayGainMode': mode.name});

      expect(usbAudioPreferences.replayGainModeNotifier.value, mode);
      expect(usbAudioPreferences.toMap()['usbReplayGainMode'], mode.name);
    }
  });

  test('按 VID PID 保存独立 USB 音量并过滤非法数据', () {
    usbAudioPreferences.load({
      'usbExclusiveDeviceVolumes': {
        '0661:0883': 0.42,
        'GGGG:0001': 0.9,
        '1234:5678': 2,
      },
    });

    expect(usbAudioPreferences.volumeForDevice('0661:0883'), 0.42);
    expect(usbAudioPreferences.volumeForDevice('1234:5678'), 1);
    expect(usbAudioPreferences.volumeForDevice('GGGG:0001'), 0.3);
    usbAudioPreferences.setVolumeForDevice('0661:0883', 0.25);
    expect(
      (usbAudioPreferences.toMap()['usbExclusiveDeviceVolumes']
          as Map)['0661:0883'],
      0.25,
    );
  });

  test('USB 状态生成稳定 VID PID 音量键', () {
    expect(usbExclusiveVolumeDeviceKey(0x0661, 0x0883), '0661:0883');
    expect(usbExclusiveVolumeDeviceKey(null, 0x0883), isNull);
  });

  test('播放状态可单独恢复设备音量记录', () {
    usbAudioPreferences.loadDeviceVolumes({'0661:0883': 0.66});

    expect(usbAudioPreferences.volumeForDevice('0661:0883'), 0.66);
    expect(
      usbAudioPreferences.replayGainModeNotifier.value,
      ReplayGainMode.off,
    );
  });

  test('clamps foreground and background USB buffers to real limit', () {
    usbAudioPreferences.load({
      'usbForegroundBufferMs': 1400,
      'usbBackgroundBufferMs': 5000,
    });

    expect(usbAudioPreferences.foregroundBufferMsNotifier.value, 1000);
    expect(usbAudioPreferences.backgroundBufferMsNotifier.value, 1000);
  });

  test('selects exclusive PCM bit depth from user preference', () {
    usbAudioPreferences.bitDepthModeNotifier.value = UsbBitDepthMode.auto;
    expect(preferredUsbExclusiveBitDepth(), isNull);

    usbAudioPreferences.bitDepthModeNotifier.value = UsbBitDepthMode.pcm16;
    expect(preferredUsbExclusiveBitDepth(), 16);

    usbAudioPreferences.bitDepthModeNotifier.value = UsbBitDepthMode.pcm24;
    expect(preferredUsbExclusiveBitDepth(), 24);

    usbAudioPreferences.bitDepthModeNotifier.value = UsbBitDepthMode.pcm32;
    expect(preferredUsbExclusiveBitDepth(), 32);
  });

  test('maps exclusive digital volume with finer low end', () {
    expect(usbExclusiveDigitalVolumeGain(-1), 0);
    expect(usbExclusiveDigitalVolumeGain(0), 0);
    expect(usbExclusiveDigitalVolumeGain(0.01), closeTo(0.001, 0.000001));
    expect(usbExclusiveDigitalVolumeGain(0.5), closeTo(0.353553, 0.000001));
    expect(usbExclusiveDigitalVolumeGain(1), 1);
    expect(usbExclusiveDigitalVolumeGain(2), 1);
  });

  test('ignores unsupported fixed sample rate', () {
    usbAudioPreferences.load({
      'usbFixedSampleRateEnabled': true,
      'usbFixedSampleRate': 12345,
    });

    expect(usbAudioPreferences.preferredFixedSampleRate(), isNull);
  });
}
