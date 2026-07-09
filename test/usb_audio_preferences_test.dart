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
    expect(usbAudioPreferences.backgroundBufferMsNotifier.value, 2400);
    expect(usbAudioPreferences.volumeSmoothHandoffNotifier.value, isFalse);
    final map = usbAudioPreferences.toMap();
    expect(map['usbDsdMode'], 'native');
    expect(map['usbForegroundBufferMs'], 320);
    expect(map, isNot(contains('usbBusSpeedMode')));
    expect(map, isNot(contains('usbBitDepthCompat')));
    expect(map, isNot(contains('usbSampleRateCompat')));
    expect(map, isNot(contains('usbChannelCompat')));
    expect(map, isNot(contains('usbTpdfDither')));
    expect(map, isNot(contains('usbDelayedUsbLink')));
  });

  test('uses practical defaults for USB buffer and volume options', () {
    usbAudioPreferences.load(const {});

    expect(usbAudioPreferences.foregroundBufferMsNotifier.value, 200);
    expect(usbAudioPreferences.backgroundBufferMsNotifier.value, 1500);
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
    expect(preferredUsbExclusiveTargetBufferMs(background: true), 2400);

    usbAudioPreferences.keepAliveInBackgroundNotifier.value = false;
    expect(preferredUsbExclusiveTargetBufferMs(background: true), 320);
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
