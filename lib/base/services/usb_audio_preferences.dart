import 'dart:math' as math;

import 'package:flutter/foundation.dart';

final usbAudioPreferences = UsbAudioPreferences();

int preferredUsbExclusiveTargetBufferMs({required bool background}) {
  if (background && usbAudioPreferences.keepAliveInBackgroundNotifier.value) {
    return usbAudioPreferences.backgroundBufferMsNotifier.value;
  }
  return usbAudioPreferences.foregroundBufferMsNotifier.value;
}

int? preferredUsbExclusiveBitDepth() {
  return switch (usbAudioPreferences.bitDepthModeNotifier.value) {
    UsbBitDepthMode.auto => null,
    UsbBitDepthMode.pcm16 => 16,
    UsbBitDepthMode.pcm24 => 24,
    UsbBitDepthMode.pcm32 => 32,
  };
}

double usbExclusiveDigitalVolumeGain(double volume) {
  final safeVolume = volume.clamp(0.0, 1.0).toDouble();
  if (safeVolume <= 0) {
    return 0;
  }
  return math.pow(safeVolume, 1.5).toDouble();
}

enum UsbDsdMode { pcm, dop, native }

enum ReplayGainMode { track, album, off }

/// 独占音量控制方式：自动/DAC 硬件音量/数字音量/原始数字电平。
enum UsbVolumeControlMode { auto, dac, digital, raw }

enum UsbBitDepthMode { auto, pcm16, pcm24, pcm32 }

class UsbAudioPreferences {
  static const sampleRates = [44100, 48000, 88200, 96000, 176400, 192000];
  static const defaultExclusiveVolume = 0.3;

  final fixedSampleRateEnabledNotifier = ValueNotifier(false);
  final fixedSampleRateNotifier = ValueNotifier<int?>(null);
  final dsdModeNotifier = ValueNotifier(UsbDsdMode.dop);
  final dsd64PcmRateNotifier = ValueNotifier(88200);
  final dsd128PcmRateNotifier = ValueNotifier(88200);
  final dsd256PcmRateNotifier = ValueNotifier(88200);
  final dsd512PcmRateNotifier = ValueNotifier(88200);
  final performanceModeNotifier = ValueNotifier(true);
  final replayGainModeNotifier = ValueNotifier(ReplayGainMode.off);
  final volumeControlModeNotifier = ValueNotifier(UsbVolumeControlMode.auto);
  final dsdGainCompensationNotifier = ValueNotifier(0);
  final bitDepthModeNotifier = ValueNotifier(UsbBitDepthMode.auto);
  final releaseUsbBandwidthAfterPlaybackNotifier = ValueNotifier(false);
  final keepAliveInBackgroundNotifier = ValueNotifier(true);
  final foregroundBufferMsNotifier = ValueNotifier(200);
  final backgroundBufferMsNotifier = ValueNotifier(1000);
  final volumeSmoothHandoffNotifier = ValueNotifier(true);
  final Map<String, double> _exclusiveDeviceVolumes = {};

  void load(Map<String, dynamic> json) {
    _exclusiveDeviceVolumes.clear();
    final deviceVolumes = json['usbExclusiveDeviceVolumes'];
    if (deviceVolumes is Map) {
      for (final entry in deviceVolumes.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is num && value.isFinite) {
          setVolumeForDevice(key, value.toDouble());
        }
      }
    }
    fixedSampleRateEnabledNotifier.value =
        json['usbFixedSampleRateEnabled'] as bool? ?? false;
    fixedSampleRateNotifier.value = _validRate(
      json['usbFixedSampleRate'] as int?,
    );
    dsdModeNotifier.value = _enumByName(
      UsbDsdMode.values,
      json['usbDsdMode'] as String?,
      UsbDsdMode.dop,
    );
    dsd64PcmRateNotifier.value =
        _validRate(json['usbDsd64PcmRate'] as int?) ?? 88200;
    dsd128PcmRateNotifier.value =
        _validRate(json['usbDsd128PcmRate'] as int?) ?? 88200;
    dsd256PcmRateNotifier.value =
        _validRate(json['usbDsd256PcmRate'] as int?) ?? 88200;
    dsd512PcmRateNotifier.value =
        _validRate(json['usbDsd512PcmRate'] as int?) ?? 88200;
    performanceModeNotifier.value = json['usbPerformanceMode'] as bool? ?? true;
    replayGainModeNotifier.value = _enumByName(
      ReplayGainMode.values,
      json['usbReplayGainMode'] as String?,
      ReplayGainMode.off,
    );
    volumeControlModeNotifier.value = _enumByName(
      UsbVolumeControlMode.values,
      json['usbVolumeControlMode'] as String?,
      UsbVolumeControlMode.auto,
    );
    dsdGainCompensationNotifier.value =
        json['usbDsdGainCompensation'] as int? ?? 0;
    bitDepthModeNotifier.value = _enumByName(
      UsbBitDepthMode.values,
      json['usbBitDepthMode'] as String?,
      UsbBitDepthMode.auto,
    );
    releaseUsbBandwidthAfterPlaybackNotifier.value =
        json['usbReleaseBandwidthAfterPlayback'] as bool? ?? false;
    keepAliveInBackgroundNotifier.value =
        json['usbKeepAliveInBackground'] as bool? ?? true;
    foregroundBufferMsNotifier.value = _validBufferMs(
      json['usbForegroundBufferMs'] as int?,
      200,
    );
    backgroundBufferMsNotifier.value = _validBufferMs(
      json['usbBackgroundBufferMs'] as int?,
      1000,
    );
    volumeSmoothHandoffNotifier.value =
        json['usbVolumeSmoothHandoff'] as bool? ?? true;
  }

  Map<String, Object?> toMap() {
    return {
      'usbFixedSampleRateEnabled': fixedSampleRateEnabledNotifier.value,
      'usbFixedSampleRate': fixedSampleRateNotifier.value,
      'usbDsdMode': dsdModeNotifier.value.name,
      'usbDsd64PcmRate': dsd64PcmRateNotifier.value,
      'usbDsd128PcmRate': dsd128PcmRateNotifier.value,
      'usbDsd256PcmRate': dsd256PcmRateNotifier.value,
      'usbDsd512PcmRate': dsd512PcmRateNotifier.value,
      'usbPerformanceMode': performanceModeNotifier.value,
      'usbReplayGainMode': replayGainModeNotifier.value.name,
      'usbVolumeControlMode': volumeControlModeNotifier.value.name,
      'usbDsdGainCompensation': dsdGainCompensationNotifier.value,
      'usbBitDepthMode': bitDepthModeNotifier.value.name,
      'usbReleaseBandwidthAfterPlayback':
          releaseUsbBandwidthAfterPlaybackNotifier.value,
      'usbKeepAliveInBackground': keepAliveInBackgroundNotifier.value,
      'usbForegroundBufferMs': foregroundBufferMsNotifier.value,
      'usbBackgroundBufferMs': backgroundBufferMsNotifier.value,
      'usbVolumeSmoothHandoff': volumeSmoothHandoffNotifier.value,
      'usbExclusiveDeviceVolumes': Map<String, double>.unmodifiable(
        _exclusiveDeviceVolumes,
      ),
    };
  }

  double volumeForDevice(String? key) {
    if (key == null) return defaultExclusiveVolume;
    return _exclusiveDeviceVolumes[key.toLowerCase()] ?? defaultExclusiveVolume;
  }

  void setVolumeForDevice(String? key, double volume) {
    final normalized = key?.toLowerCase();
    if (normalized == null ||
        !RegExp(r'^[0-9a-f]{4}:[0-9a-f]{4}$').hasMatch(normalized)) {
      return;
    }
    _exclusiveDeviceVolumes[normalized] = volume.clamp(0.0, 1.0).toDouble();
  }

  int? preferredFixedSampleRate() {
    if (!fixedSampleRateEnabledNotifier.value) {
      return null;
    }
    return _validRate(fixedSampleRateNotifier.value);
  }

  String preferredEncoding() {
    return switch (bitDepthModeNotifier.value) {
      UsbBitDepthMode.pcm16 => 'pcm_16bit',
      UsbBitDepthMode.pcm24 => 'pcm_24bit_packed',
      UsbBitDepthMode.pcm32 => 'pcm_32bit',
      UsbBitDepthMode.auto => 'pcm_24bit_packed',
    };
  }

  void resetForTest() {
    load(const {});
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }

  int? _validRate(int? rate) {
    if (rate == null) return null;
    return sampleRates.contains(rate) ? rate : null;
  }

  int _validBufferMs(int? value, int fallback) {
    if (value == null) return fallback;
    return value.clamp(50, 1000);
  }
}
