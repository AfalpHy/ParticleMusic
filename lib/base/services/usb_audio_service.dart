import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';

final usbAudioService = UsbAudioService();
final usbAudioStatusNotifier = ValueNotifier(UsbAudioStatus.unavailable());
final usbAudioEventNotifier = ValueNotifier<UsbAudioDeviceEvent?>(null);
final usbExclusivePlaybackStateNotifier = ValueNotifier(
  UsbExclusivePlaybackState.inactive(),
);
final usbTransportTelemetryNotifier = ValueNotifier(
  UsbTransportTelemetry.inactive(),
);
final usbHardwareVolumeNotifier = ValueNotifier<UsbHardwareVolumeEvent?>(null);
final usbVolumeOverlayNotifier = ValueNotifier<int>(0);
final usbExclusiveVolumeKeyNotifier = ValueNotifier<int>(0);

Duration trustedUsbExclusivePosition({
  required Duration current,
  required Duration reported,
  required bool stateActive,
}) {
  if (stateActive) return reported;
  return reported > current ? reported : current;
}

enum UsbAudioDeviceEventType { added, removed }

class UsbAudioService {
  static const MethodChannel _defaultChannel = MethodChannel(
    'com.afalphy.sylvakru/usb_audio',
  );

  final MethodChannel _channel;
  final bool _isAndroid;
  String? _currentPlaybackId;

  UsbAudioService({MethodChannel channel = _defaultChannel, bool? isAndroid})
    : _channel = channel,
      _isAndroid = isAndroid ?? Platform.isAndroid {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<UsbAudioStatus> refreshStatus() async {
    if (!_isAndroid) {
      final status = UsbAudioStatus.unavailable(
        message: 'USB audio optimization is only available on Android.',
      );
      usbAudioStatusNotifier.value = status;
      return status;
    }

    return _invokeStatus('getStatus');
  }

  Future<UsbAudioStatus> applyPreferredOutput({
    int? deviceId,
    int? sampleRate,
    String encoding = 'pcm_24bit_packed',
    bool bitPerfect = true,
  }) async {
    if (!_isAndroid) {
      final status = UsbAudioStatus.unavailable(
        message: 'USB audio optimization is only available on Android.',
      );
      usbAudioStatusNotifier.value = status;
      return status;
    }

    return _invokeStatus('applyPreferredOutput', {
      'deviceId': ?deviceId,
      'sampleRate': ?sampleRate,
      'encoding': encoding,
      'bitPerfect': bitPerfect,
    });
  }

  Future<UsbAudioStatus> clearPreferredOutput() async {
    if (!_isAndroid) {
      final status = UsbAudioStatus.unavailable(
        message: 'USB audio optimization is only available on Android.',
      );
      usbAudioStatusNotifier.value = status;
      return status;
    }

    return _invokeStatus('clearPreferredOutput');
  }

  Future<UsbExclusiveProbeResult> probeExclusiveAccess() async {
    if (!_isAndroid) {
      return const UsbExclusiveProbeResult(
        supported: false,
        permissionGranted: false,
        deviceName: null,
        deviceId: null,
        audioInterfaceCount: 0,
        claimedInterfaceCount: 0,
        rawDescriptorLength: 0,
        message: 'USB exclusive access probing is only available on Android.',
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'probeExclusiveAccess',
      );
      return UsbExclusiveProbeResult.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return UsbExclusiveProbeResult(
        supported: false,
        permissionGranted: false,
        deviceName: null,
        deviceId: null,
        audioInterfaceCount: 0,
        claimedInterfaceCount: 0,
        rawDescriptorLength: 0,
        message: error.message,
      );
    }
  }

  Future<UsbExclusiveCapability> getExclusiveCapabilities() async {
    if (!_isAndroid) {
      return const UsbExclusiveCapability(
        available: false,
        permissionGranted: false,
        deviceName: null,
        deviceId: null,
        interfaceNumber: null,
        alternateSetting: null,
        endpointAddress: null,
        maxPacketSize: null,
        sampleRates: [],
        bitDepths: [],
        channelCounts: [],
        message: 'USB exclusive playback is only available on Android.',
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getExclusiveCapabilities',
      );
      return UsbExclusiveCapability.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return UsbExclusiveCapability.unavailable(message: error.message);
    }
  }

  Future<UsbExclusivePlaybackState> startExclusivePlayback(
    UsbExclusivePlaybackRequest request,
  ) {
    _currentPlaybackId = request.playbackId;
    return _invokeExclusiveState('startExclusivePlayback', request.toMap());
  }

  Future<UsbExclusivePlaybackState> pauseExclusivePlayback() {
    return _invokeExclusiveState('pauseExclusivePlayback');
  }

  Future<UsbExclusivePlaybackState> resumeExclusivePlayback() {
    return _invokeExclusiveState('resumeExclusivePlayback');
  }

  void markExclusiveDeviceRemoved({required Duration position}) {
    final current = usbExclusivePlaybackStateNotifier.value;
    if (!current.active) return;
    _publishExclusiveState(
      UsbExclusivePlaybackState.inactive(
        playbackId: current.playbackId,
        position: position,
        duration: current.duration,
        message: 'USB audio device removed.',
      ),
    );
  }

  Future<void> setExclusiveTargetBufferMs(int targetBufferMs) async {
    if (!_isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('setExclusiveTargetBufferMs', {
      'targetBufferMs': targetBufferMs.clamp(50, 1000),
    });
  }

  /// 设置独占音量。原生层按 mode 选择 DAC 硬件音量、PCM 数字音量或原始电平。
  Future<void> setExclusiveVolume({
    required double gain,
    required double replayGainDb,
    required String mode,
    required int dsdGainCompensationDb,
    required bool smoothHandoff,
  }) async {
    if (!_isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('setExclusiveVolume', {
      'gainQ16': (gain.clamp(0.0, 1.0) * 65536).round(),
      'replayGainMilliDb': _replayGainMilliDb(replayGainDb),
      'mode': mode,
      'dsdGainCompensationDb': dsdGainCompensationDb.clamp(-12, 6),
      'smoothHandoff': smoothHandoff,
    });
  }

  Future<UsbExclusivePlaybackState> seekExclusivePlayback(Duration position) {
    return _invokeExclusiveState('seekExclusivePlayback', {
      'positionMs': position.inMilliseconds,
    });
  }

  Future<UsbExclusivePlaybackState> stopExclusivePlayback() {
    return _invokeExclusiveState('stopExclusivePlayback');
  }

  Future<UsbExclusivePlaybackState> releaseExclusiveDevice() {
    return _invokeExclusiveState('releaseExclusiveDevice');
  }

  /// 导入 quirk 配置 JSON（写入本地 override 文件，优先级高于内置 asset）。
  /// 返回 null 表示成功，否则为错误描述。
  Future<String?> importDacQuirks(String json) async {
    if (!_isAndroid) {
      return 'Only available on Android.';
    }
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'importUsbDacQuirks',
        {'json': json},
      );
      if (result?['ok'] == true) {
        return null;
      }
      return result?['error'] as String? ?? 'Unknown error.';
    } on PlatformException catch (error) {
      return error.message ?? error.code;
    }
  }

  /// 生成一键复制/导出的 DAC 适配诊断报告（纯文本 Markdown）。
  /// 报告不要求 DAC 在线：未连接设备时也会带上环境、偏好与最近日志。
  Future<String> getDiagnosticsReport() async {
    Map<String, Object?> native = const {};
    if (_isAndroid) {
      try {
        native =
            await _channel.invokeMapMethod<String, Object?>(
              'getUsbDiagnosticsReport',
            ) ??
            const {};
      } on PlatformException catch (error) {
        native = {'error': error.message};
      }
    }
    return buildUsbDiagnosticsReport(native, platformSupported: _isAndroid);
  }

  Future<UsbAudioStatus> _invokeStatus(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      final status = UsbAudioStatus.fromMap(result ?? const {});
      usbAudioStatusNotifier.value = status;
      return status;
    } on PlatformException catch (error) {
      final status = UsbAudioStatus.unavailable(message: error.message);
      usbAudioStatusNotifier.value = status;
      return status;
    }
  }

  Future<UsbExclusivePlaybackState> _invokeExclusiveState(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!_isAndroid) {
      final state = UsbExclusivePlaybackState.inactive(
        playbackId: _currentPlaybackId,
        message: 'USB exclusive playback is only available on Android.',
      );
      usbExclusivePlaybackStateNotifier.value = state;
      return state;
    }

    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      final state = UsbExclusivePlaybackState.fromMap(result ?? const {});
      _publishExclusiveState(state);
      return state;
    } on PlatformException catch (error) {
      final state = UsbExclusivePlaybackState.inactive(
        playbackId: _currentPlaybackId,
        message: error.message,
      );
      _publishExclusiveState(state);
      return state;
    }
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onUsbAudioDeviceEvent') {
      final event = UsbAudioDeviceEvent.fromMap(
        (call.arguments as Map).cast<String, Object?>(),
      );
      usbAudioStatusNotifier.value = event.status;
      usbAudioEventNotifier.value = event;
      return null;
    }

    if (call.method == 'onUsbExclusiveStateChanged' ||
        call.method == 'onUsbExclusivePosition' ||
        call.method == 'onUsbExclusiveError') {
      final state = UsbExclusivePlaybackState.fromMap(
        (call.arguments as Map?)?.cast<String, Object?>() ?? const {},
      );
      _publishExclusiveState(state);
      return null;
    }

    if (call.method == 'onUsbExclusiveVolumeKey') {
      final direction =
          _asInt((call.arguments as Map?)?['direction'] as Object?) ?? 0;
      if (direction != 0) {
        usbExclusiveVolumeKeyNotifier.value += direction;
      }
      return null;
    }

    if (call.method == 'onUsbHardwareVolumeChanged') {
      final event = UsbHardwareVolumeEvent.fromMap(
        (call.arguments as Map?)?.cast<String, Object?>() ?? const {},
      );
      if (event != null) {
        usbHardwareVolumeNotifier.value = event;
      }
      return null;
    }

    if (call.method == 'onUsbTransportTelemetryChanged') {
      final telemetry = UsbTransportTelemetry.fromMap(
        (call.arguments as Map?)?.cast<String, Object?>() ?? const {},
      );
      usbTransportTelemetryNotifier.value = telemetry;
      return null;
    }

    throw PlatformException(
      code: 'unimplemented',
      message: 'Unknown USB audio callback: ${call.method}',
    );
  }

  void _publishExclusiveState(UsbExclusivePlaybackState state) {
    final playbackId = state.playbackId;
    if (playbackId != null &&
        _currentPlaybackId != null &&
        playbackId != _currentPlaybackId) {
      return;
    }
    usbExclusivePlaybackStateNotifier.value = state;
  }
}

@immutable
class UsbHardwareVolumeEvent {
  final String playbackId;
  final int gainQ16;
  final int leftRaw;
  final int rightRaw;
  final String protocol;
  final bool isDsd;
  final int replayGainMilliDb;
  final int dsdGainCompensationDb;

  const UsbHardwareVolumeEvent({
    required this.playbackId,
    required this.gainQ16,
    required this.leftRaw,
    required this.rightRaw,
    required this.protocol,
    required this.isDsd,
    required this.replayGainMilliDb,
    required this.dsdGainCompensationDb,
  });

  static UsbHardwareVolumeEvent? fromMap(Map<String, Object?> map) {
    final playbackId = map['playbackId'];
    final gainQ16 = _asInt(map['gainQ16']);
    final leftRaw = _asInt(map['leftRaw']);
    final rightRaw = _asInt(map['rightRaw']);
    final protocol = map['protocol'];
    final isDsd = map['isDsd'];
    final replayGainMilliDb = _asInt(map['replayGainMilliDb']);
    final dsdGainCompensationDb = _asInt(map['dsdGainCompensationDb']);
    if (playbackId is! String ||
        playbackId.isEmpty ||
        gainQ16 == null ||
        gainQ16 < 0 ||
        gainQ16 > 65536 ||
        leftRaw == null ||
        rightRaw == null ||
        protocol is! String ||
        protocol.isEmpty ||
        isDsd is! bool ||
        replayGainMilliDb == null ||
        dsdGainCompensationDb == null) {
      return null;
    }
    return UsbHardwareVolumeEvent(
      playbackId: playbackId,
      gainQ16: gainQ16,
      leftRaw: leftRaw,
      rightRaw: rightRaw,
      protocol: protocol,
      isDsd: isDsd,
      replayGainMilliDb: replayGainMilliDb,
      dsdGainCompensationDb: dsdGainCompensationDb,
    );
  }
}

@immutable
class UsbExclusiveCapability {
  final bool available;
  final bool permissionGranted;
  final String? deviceName;
  final int? deviceId;
  final int? interfaceNumber;
  final int? alternateSetting;
  final int? endpointAddress;
  final int? maxPacketSize;
  final List<int> sampleRates;
  final List<int> bitDepths;
  final List<int> channelCounts;
  final String? message;

  const UsbExclusiveCapability({
    required this.available,
    required this.permissionGranted,
    required this.deviceName,
    required this.deviceId,
    required this.interfaceNumber,
    required this.alternateSetting,
    required this.endpointAddress,
    required this.maxPacketSize,
    required this.sampleRates,
    required this.bitDepths,
    required this.channelCounts,
    required this.message,
  });

  factory UsbExclusiveCapability.unavailable({String? message}) {
    return UsbExclusiveCapability(
      available: false,
      permissionGranted: false,
      deviceName: null,
      deviceId: null,
      interfaceNumber: null,
      alternateSetting: null,
      endpointAddress: null,
      maxPacketSize: null,
      sampleRates: const [],
      bitDepths: const [],
      channelCounts: const [],
      message: message,
    );
  }

  factory UsbExclusiveCapability.fromMap(Map<String, Object?> map) {
    return UsbExclusiveCapability(
      available: map['available'] == true,
      permissionGranted: map['permissionGranted'] == true,
      deviceName: map['deviceName'] as String?,
      deviceId: _asInt(map['deviceId']),
      interfaceNumber: _asInt(map['interfaceNumber']),
      alternateSetting: _asInt(map['alternateSetting']),
      endpointAddress: _asInt(map['endpointAddress']),
      maxPacketSize: _asInt(map['maxPacketSize']),
      sampleRates: _asIntList(map['sampleRates']),
      bitDepths: _asIntList(map['bitDepths']),
      channelCounts: _asIntList(map['channelCounts']),
      message: map['message'] as String?,
    );
  }
}

@immutable
class UsbExclusivePlaybackRequest {
  final String playbackId;
  final String filePath;
  final String? title;
  final String? sourceFormat;
  final int? sampleRate;
  final int? bitDepth;

  /// DSD 文件的输出模式（UsbDsdMode.name：dop/native），非 DSD 为 null
  final String? dsdMode;
  final double volumeGain;
  final double replayGainDb;
  final String volumeMode;
  final int dsdGainCompensationDb;
  final bool smoothVolumeHandoff;
  final int? targetBufferMs;
  final bool startPaused;

  /// filePath 是仍在下载增长中的 .part 缓存文件（流式独占）
  final bool streaming;

  /// 流式独占用的完整文件字节数估算（时长×码率，偏大）；引擎据此让
  /// MediaExtractor 能对增长中的 .part 正确 seek，0/null 表示未知（回退旧行为）
  final int? totalBytes;

  const UsbExclusivePlaybackRequest({
    required this.playbackId,
    required this.filePath,
    required this.title,
    required this.sourceFormat,
    required this.sampleRate,
    required this.bitDepth,
    this.dsdMode,
    required this.volumeGain,
    this.replayGainDb = 0,
    required this.volumeMode,
    this.dsdGainCompensationDb = 0,
    this.smoothVolumeHandoff = true,
    required this.targetBufferMs,
    required this.startPaused,
    this.streaming = false,
    this.totalBytes,
  });

  Map<String, Object?> toMap() {
    return {
      'playbackId': playbackId,
      'filePath': filePath,
      'title': title,
      'sourceFormat': sourceFormat,
      'sampleRate': sampleRate,
      'bitDepth': bitDepth,
      'dsdMode': dsdMode,
      'volumeGainQ16': (volumeGain.clamp(0.0, 1.0) * 65536).round(),
      'replayGainMilliDb': _replayGainMilliDb(replayGainDb),
      'volumeMode': volumeMode,
      'dsdGainCompensationDb': dsdGainCompensationDb.clamp(-12, 6),
      'smoothHandoff': smoothVolumeHandoff,
      'targetBufferMs': targetBufferMs,
      'startPaused': startPaused,
      'streaming': streaming,
      'totalBytes': totalBytes,
    };
  }
}

int _replayGainMilliDb(double gainDb) {
  if (!gainDb.isFinite) {
    return 0;
  }
  const maximum = 2147483647;
  const minimum = -2147483648;
  if (gainDb >= maximum / 1000) {
    return maximum;
  }
  if (gainDb <= minimum / 1000) {
    return minimum;
  }
  return (gainDb * 1000).round();
}

@immutable
class UsbExclusivePlaybackState {
  final String? playbackId;
  final bool active;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final int? sampleRate;
  final int? bitDepth;
  final int? sourceBitDepth;
  final int? decodedBitDepth;
  final int? usbBitDepth;
  final bool? bitPerfect;
  final String? format;
  final bool hardwareVolumeActive;
  final bool digitalVolumeActive;
  final bool hardwareVolumeWriteOnly;
  final bool hardwareVolumeReadbackVerified;
  final bool hardwareVolumeSyncPending;
  final bool hardwareVolumeFrozen;
  final String? hardwareVolumeProtocol;
  final int? hardwareVolumeRaw;
  final int? hardwareVolumeGainQ16;
  final int replayGainMilliDb;
  final String? message;

  bool get hardwareVolumeUnverified =>
      hardwareVolumeActive && !hardwareVolumeReadbackVerified;

  const UsbExclusivePlaybackState({
    required this.playbackId,
    required this.active,
    required this.playing,
    required this.position,
    required this.duration,
    required this.sampleRate,
    required this.bitDepth,
    this.sourceBitDepth,
    this.decodedBitDepth,
    this.usbBitDepth,
    this.bitPerfect,
    required this.format,
    required this.hardwareVolumeActive,
    required this.digitalVolumeActive,
    required this.hardwareVolumeWriteOnly,
    required this.hardwareVolumeReadbackVerified,
    required this.hardwareVolumeSyncPending,
    required this.hardwareVolumeFrozen,
    required this.hardwareVolumeProtocol,
    required this.hardwareVolumeRaw,
    required this.hardwareVolumeGainQ16,
    required this.replayGainMilliDb,
    required this.message,
  });

  factory UsbExclusivePlaybackState.inactive({
    String? playbackId,
    Duration position = Duration.zero,
    Duration? duration,
    String? message,
  }) {
    return UsbExclusivePlaybackState(
      playbackId: playbackId,
      active: false,
      playing: false,
      position: position,
      duration: duration,
      sampleRate: null,
      bitDepth: null,
      format: null,
      hardwareVolumeActive: false,
      digitalVolumeActive: false,
      hardwareVolumeWriteOnly: false,
      hardwareVolumeReadbackVerified: false,
      hardwareVolumeSyncPending: false,
      hardwareVolumeFrozen: false,
      hardwareVolumeProtocol: null,
      hardwareVolumeRaw: null,
      hardwareVolumeGainQ16: null,
      replayGainMilliDb: 0,
      message: message,
    );
  }

  factory UsbExclusivePlaybackState.fromMap(Map<String, Object?> map) {
    return UsbExclusivePlaybackState(
      playbackId: map['playbackId'] as String?,
      active: map['active'] == true,
      playing: map['playing'] == true,
      position: Duration(milliseconds: _asInt(map['positionMs']) ?? 0),
      duration: _asInt(map['durationMs']) == null
          ? null
          : Duration(milliseconds: _asInt(map['durationMs'])!),
      sampleRate: _asInt(map['sampleRate']),
      bitDepth: _asInt(map['bitDepth']),
      sourceBitDepth: _asInt(map['sourceBitDepth']),
      decodedBitDepth: _asInt(map['decodedBitDepth']),
      usbBitDepth: _asInt(map['usbBitDepth']),
      bitPerfect: map['bitPerfect'] as bool?,
      format: map['format'] as String?,
      hardwareVolumeActive: map['hardwareVolumeActive'] == true,
      digitalVolumeActive: map['digitalVolumeActive'] == true,
      hardwareVolumeWriteOnly: map['hardwareVolumeWriteOnly'] == true,
      hardwareVolumeReadbackVerified:
          map['hardwareVolumeReadbackVerified'] == true,
      hardwareVolumeSyncPending: map['hardwareVolumeSyncPending'] == true,
      hardwareVolumeFrozen: map['hardwareVolumeFrozen'] == true,
      hardwareVolumeProtocol: map['hardwareVolumeProtocol'] as String?,
      hardwareVolumeRaw: _asInt(map['hardwareVolumeRaw']),
      hardwareVolumeGainQ16: _asInt(map['hardwareVolumeGainQ16']),
      replayGainMilliDb: _asInt(map['replayGainMilliDb']) ?? 0,
      message: map['message'] as String?,
    );
  }
}

@immutable
class UsbTransportTelemetry {
  final bool active;
  final Duration bufferLevel;
  final Duration? minimumBufferLevel;
  final Duration? targetBuffer;
  final int isoPacketCount;
  final int pendingUrbs;
  final int underrunCount;
  final int? lastUnderrunAtMs;
  final int updatedAtMs;

  const UsbTransportTelemetry({
    required this.active,
    required this.bufferLevel,
    required this.minimumBufferLevel,
    required this.targetBuffer,
    required this.isoPacketCount,
    required this.pendingUrbs,
    required this.underrunCount,
    required this.lastUnderrunAtMs,
    required this.updatedAtMs,
  });

  factory UsbTransportTelemetry.inactive() {
    return const UsbTransportTelemetry(
      active: false,
      bufferLevel: Duration.zero,
      minimumBufferLevel: null,
      targetBuffer: null,
      isoPacketCount: 0,
      pendingUrbs: 0,
      underrunCount: 0,
      lastUnderrunAtMs: null,
      updatedAtMs: 0,
    );
  }

  factory UsbTransportTelemetry.fromMap(Map<String, Object?> map) {
    return UsbTransportTelemetry(
      active: map['active'] == true,
      bufferLevel: Duration(
        milliseconds: _asInt(map['bufferLevelMs'])?.clamp(0, 60000) ?? 0,
      ),
      minimumBufferLevel: _durationFromMs(map['minimumBufferLevelMs']),
      targetBuffer: _durationFromMs(map['targetBufferMs']),
      isoPacketCount: _asInt(map['isoPacketCount']) ?? 0,
      pendingUrbs: _asInt(map['pendingUrbs']) ?? 0,
      underrunCount: _asInt(map['underrunCount']) ?? 0,
      lastUnderrunAtMs: _asInt(map['lastUnderrunAtMs']),
      updatedAtMs: _asInt(map['updatedAtMs']) ?? 0,
    );
  }

  UsbTransportHealth health({required bool playing, required int targetMs}) {
    if (!active) return UsbTransportHealth.idle;
    if (!playing) return UsbTransportHealth.paused;
    if (lastUnderrunAtMs != null &&
        updatedAtMs >= lastUnderrunAtMs! &&
        updatedAtMs - lastUnderrunAtMs! <= 1500) {
      return UsbTransportHealth.underrun;
    }

    final lowWatermark = (targetMs * 0.35).round().clamp(20, 250);
    return bufferLevel.inMilliseconds < lowWatermark
        ? UsbTransportHealth.low
        : UsbTransportHealth.stable;
  }
}

enum UsbTransportHealth { idle, paused, stable, low, underrun }

@immutable
class UsbExclusiveProbeResult {
  final bool supported;
  final bool permissionGranted;
  final String? deviceName;
  final int? deviceId;
  final int audioInterfaceCount;
  final int claimedInterfaceCount;
  final int rawDescriptorLength;
  final String? message;

  const UsbExclusiveProbeResult({
    required this.supported,
    required this.permissionGranted,
    required this.deviceName,
    required this.deviceId,
    required this.audioInterfaceCount,
    required this.claimedInterfaceCount,
    required this.rawDescriptorLength,
    required this.message,
  });

  factory UsbExclusiveProbeResult.fromMap(Map<String, Object?> map) {
    return UsbExclusiveProbeResult(
      supported: map['supported'] == true,
      permissionGranted: map['permissionGranted'] == true,
      deviceName: map['deviceName'] as String?,
      deviceId: _asInt(map['deviceId']),
      audioInterfaceCount: _asInt(map['audioInterfaceCount']) ?? 0,
      claimedInterfaceCount: _asInt(map['claimedInterfaceCount']) ?? 0,
      rawDescriptorLength: _asInt(map['rawDescriptorLength']) ?? 0,
      message: map['message'] as String?,
    );
  }

  bool get interfaceClaimed => claimedInterfaceCount > 0;
}

@immutable
class UsbAudioDeviceEvent {
  final UsbAudioDeviceEventType type;
  final int? deviceId;
  final UsbAudioStatus status;

  const UsbAudioDeviceEvent({
    required this.type,
    required this.deviceId,
    required this.status,
  });

  factory UsbAudioDeviceEvent.fromMap(Map<String, Object?> map) {
    return UsbAudioDeviceEvent(
      type: map['type'] == 'removed'
          ? UsbAudioDeviceEventType.removed
          : UsbAudioDeviceEventType.added,
      deviceId: _asInt(map['deviceId']),
      status: UsbAudioStatus.fromMap(
        (map['status'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
    );
  }
}

@immutable
class UsbAudioStatus {
  final bool supported;
  final int androidSdk;
  final int? activeDeviceId;
  final bool preferredApplied;
  final int? preferredSampleRate;
  final String? preferredEncoding;
  final bool preferredBitPerfect;
  final String? outputDeviceName;
  final int? outputSampleRate;
  final String? outputEncoding;
  final String? manufacturerName;
  final String? productName;
  final int? vendorId;
  final int? productId;
  final String? message;
  final List<UsbAudioDevice> devices;

  const UsbAudioStatus({
    required this.supported,
    required this.androidSdk,
    required this.activeDeviceId,
    required this.preferredApplied,
    required this.preferredSampleRate,
    required this.preferredEncoding,
    required this.preferredBitPerfect,
    required this.outputDeviceName,
    required this.outputSampleRate,
    required this.outputEncoding,
    required this.manufacturerName,
    required this.productName,
    required this.vendorId,
    required this.productId,
    required this.message,
    required this.devices,
  });

  factory UsbAudioStatus.unavailable({String? message}) {
    return UsbAudioStatus(
      supported: false,
      androidSdk: 0,
      activeDeviceId: null,
      preferredApplied: false,
      preferredSampleRate: null,
      preferredEncoding: null,
      preferredBitPerfect: false,
      outputDeviceName: null,
      outputSampleRate: null,
      outputEncoding: null,
      manufacturerName: null,
      productName: null,
      vendorId: null,
      productId: null,
      message: message,
      devices: const [],
    );
  }

  factory UsbAudioStatus.fromMap(Map<String, Object?> map) {
    final devicesRaw = map['devices'];
    final devices = devicesRaw is List
        ? devicesRaw
              .whereType<Map>()
              .map(
                (device) =>
                    UsbAudioDevice.fromMap(device.cast<String, Object?>()),
              )
              .toList(growable: false)
        : const <UsbAudioDevice>[];

    return UsbAudioStatus(
      supported: map['supported'] == true,
      androidSdk: _asInt(map['androidSdk']) ?? 0,
      activeDeviceId: _asInt(map['activeDeviceId']),
      preferredApplied: map['preferredApplied'] == true,
      preferredSampleRate: _asInt(map['preferredSampleRate']),
      preferredEncoding: map['preferredEncoding'] as String?,
      preferredBitPerfect: map['preferredBitPerfect'] == true,
      outputDeviceName: map['outputDeviceName'] as String?,
      outputSampleRate: _asInt(map['outputSampleRate']),
      outputEncoding: map['outputEncoding'] as String?,
      manufacturerName: map['manufacturerName'] as String?,
      productName: map['productName'] as String?,
      vendorId: _asInt(map['vendorId']),
      productId: _asInt(map['productId']),
      message: map['message'] as String?,
      devices: devices,
    );
  }

  int? get bestAvailableDeviceId {
    if (activeDeviceId != null) {
      return activeDeviceId;
    }
    return devices.isEmpty ? null : devices.first.id;
  }

  int? get bestAvailableSampleRate {
    final deviceId = bestAvailableDeviceId;
    if (deviceId == null) {
      return null;
    }
    for (final device in devices) {
      if (device.id == deviceId) {
        return device.bestSampleRate;
      }
    }
    return null;
  }
}

@immutable
class UsbAudioDevice {
  final int id;
  final String name;
  final String type;
  final String? address;
  final List<int> sampleRates;
  final List<String> encodings;
  final List<int> channelCounts;
  final List<int> supportedMixerSampleRates;
  final bool supportsBitPerfectMixer;

  const UsbAudioDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.sampleRates,
    required this.encodings,
    required this.channelCounts,
    required this.supportedMixerSampleRates,
    required this.supportsBitPerfectMixer,
  });

  factory UsbAudioDevice.fromMap(Map<String, Object?> map) {
    return UsbAudioDevice(
      id: _asInt(map['id']) ?? -1,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'USB audio device',
      type: map['type'] as String? ?? 'unknown',
      address: map['address'] as String?,
      sampleRates: _asIntList(map['sampleRates']),
      encodings: _asStringList(map['encodings']),
      channelCounts: _asIntList(map['channelCounts']),
      supportedMixerSampleRates: _asIntList(map['supportedMixerSampleRates']),
      supportsBitPerfectMixer: map['supportsBitPerfectMixer'] == true,
    );
  }

  int? get bestSampleRate {
    final candidates = supportedMixerSampleRates.isNotEmpty
        ? supportedMixerSampleRates
        : sampleRates;
    if (candidates.isEmpty) {
      return null;
    }
    final validRates = candidates
        .where(UsbAudioPreferences.sampleRates.contains)
        .toSet();
    for (final rate in const [48000, 44100, 96000, 88200, 192000, 176400]) {
      if (validRates.contains(rate)) {
        return rate;
      }
    }
    return null;
  }
}

/// 把原生侧采集的诊断数据与 Dart 侧的偏好/状态/日志拼装成单个纯文本报告。
/// 首行固定为版本标识，便于后续解析工具识别。抽成顶层函数便于单元测试。
String buildUsbDiagnosticsReport(
  Map<String, Object?> native, {
  bool platformSupported = true,
}) {
  final buffer = StringBuffer();
  buffer.writeln('Sylvakru USB Diagnostics Report v2');

  final error = native['error'];
  if (error != null) {
    buffer.writeln();
    buffer.writeln('> Failed to collect native data: $error');
  }

  // 1. Environment
  buffer.writeln();
  buffer.writeln('## Environment');
  buffer.writeln('- App version: $versionNumber');
  if (!platformSupported) {
    buffer.writeln('- Platform: non-Android (native USB data unavailable)');
  } else {
    final release = native['androidRelease'] ?? 'unknown';
    final sdk = _asInt(native['androidSdk']) ?? 'unknown';
    buffer.writeln('- Android: $release (SDK $sdk)');
    buffer.writeln(
      '- Device: ${'${native['manufacturer'] ?? 'unknown'} ${native['model'] ?? ''}'.trim()}',
    );
  }
  buffer.writeln(
    '- Generated at: ${_formatTimestamp(native['generatedAtMs'])}',
  );

  // 2. USB device identity
  buffer.writeln();
  buffer.writeln('## USB device identity');
  final device = native['device'];
  if (device is Map) {
    final d = device.cast<String, Object?>();
    buffer.writeln(
      '- VID/PID: ${d['vendorIdHex'] ?? d['vendorId']} / ${d['productIdHex'] ?? d['productId']}',
    );
    buffer.writeln('- Manufacturer: ${d['manufacturerName'] ?? 'unknown'}');
    buffer.writeln('- Product: ${d['productName'] ?? 'unknown'}');
    buffer.writeln(
      '- deviceClass/subclass: ${d['deviceClass']} / ${d['deviceSubclass']}',
    );
    buffer.writeln(
      '- Interfaces / audio interfaces: ${d['interfaceCount']} / ${d['audioInterfaceCount']}',
    );
    buffer.writeln('- Serial (masked): ${d['serialTail'] ?? 'unavailable'}');
    buffer.writeln(
      '- USB permission: ${native['permissionGranted'] == true ? 'granted' : 'denied'}',
    );
    buffer.writeln('> Only the last 4 digits of the serial are shown.');
  } else {
    buffer.writeln('- No USB audio device detected.');
  }

  final diagnostics =
      (native['diagnostics'] as Map?)?.cast<String, Object?>() ?? const {};

  // 3. Raw descriptors hex dump
  buffer.writeln();
  buffer.writeln('## Raw descriptors (hex dump)');
  final hex = diagnostics['rawDescriptorsHex'];
  if (hex is String && hex.isNotEmpty) {
    buffer.writeln(
      'Length: ${diagnostics['rawDescriptorLength'] ?? 'unknown'} bytes',
    );
    buffer.writeln('```');
    buffer.writeln(hex);
    buffer.writeln('```');
  } else {
    buffer.writeln('- ${diagnostics['message'] ?? 'Descriptors unavailable.'}');
  }

  // 4. App parse result
  buffer.writeln();
  buffer.writeln('## App parse result');
  buffer.writeln('### AS formats');
  _writeListSection(buffer, diagnostics['streamingFormats']);
  buffer.writeln(
    '### Output candidates (alt/maxPacket/attr/feedback/bits/format)',
  );
  _writeListSection(buffer, diagnostics['outputCandidates']);
  buffer.writeln(
    '- UAC2 clock source id: ${diagnostics['clockSourceId'] ?? 'unknown'}',
  );
  buffer.writeln('- Last probe: ${native['lastProbe'] ?? 'none'}');
  buffer.writeln('### Quirk');
  buffer.writeln('- Match: ${diagnostics['quirkMatch'] ?? 'unknown'}');
  buffer.writeln('- Effective: ${diagnostics['quirkEffective'] ?? 'unknown'}');
  final quirkErrors = diagnostics['quirkLoadErrors'];
  if (quirkErrors is String && quirkErrors.isNotEmpty) {
    buffer.writeln('- Load errors: $quirkErrors');
  }

  // 5. Exclusive session snapshot
  buffer.writeln();
  buffer.writeln('## Exclusive session');
  _writeDiagnosticsSnapshot(buffer, diagnostics['session']);

  // 6. Hardware volume probe
  buffer.writeln();
  buffer.writeln('## Hardware volume probe');
  _writeDiagnosticsSnapshot(buffer, diagnostics['hardwareVolume']);

  // 7. System-side capability
  buffer.writeln();
  buffer.writeln('## System-side capability');
  final status = (native['systemStatus'] as Map?)?.cast<String, Object?>();
  final devices = status?['devices'];
  if (devices is List && devices.isNotEmpty) {
    for (final dev in devices) {
      buffer.writeln('- $dev');
    }
  } else {
    buffer.writeln('- No USB audio output device.');
  }

  // 8. Preferences snapshot
  buffer.writeln();
  buffer.writeln('## Preferences snapshot');
  usbAudioPreferences.toMap().forEach((key, value) {
    buffer.writeln('- $key: $value');
  });

  // 9. Runtime state snapshot
  buffer.writeln();
  buffer.writeln('## Runtime state snapshot');
  final state = usbExclusivePlaybackStateNotifier.value;
  buffer.writeln(
    '- Exclusive: active=${state.active}, playing=${state.playing}, '
    'format=${state.format}, sampleRate=${state.sampleRate}, '
    'bitDepth=${state.bitDepth}, sourceBitDepth=${state.sourceBitDepth}, '
    'decodedBitDepth=${state.decodedBitDepth}, usbBitDepth=${state.usbBitDepth}, '
    'bitPerfect=${state.bitPerfect}, '
    'position=${state.position.inMilliseconds}ms',
  );
  buffer.writeln(
    '- Volume processing: hardware=${state.hardwareVolumeActive}, '
    'digital=${state.digitalVolumeActive}, '
    'protocol=${state.hardwareVolumeProtocol}, raw=${state.hardwareVolumeRaw}, '
    'gainQ16=${state.hardwareVolumeGainQ16}, '
    'writeOnly=${state.hardwareVolumeWriteOnly}, '
    'readbackVerified=${state.hardwareVolumeReadbackVerified}, '
    'replayGainMilliDb=${state.replayGainMilliDb}',
  );
  buffer.writeln('  message=${state.message}');
  final telemetry = usbTransportTelemetryNotifier.value;
  buffer.writeln(
    '- telemetry: active=${telemetry.active}, '
    'buffer=${telemetry.bufferLevel.inMilliseconds}ms, '
    'min=${telemetry.minimumBufferLevel?.inMilliseconds}, '
    'target=${telemetry.targetBuffer?.inMilliseconds}, '
    'iso=${telemetry.isoPacketCount}, pendingUrbs=${telemetry.pendingUrbs}, '
    'underrun=${telemetry.underrunCount}',
  );

  // 10. Recent logs
  buffer.writeln();
  buffer.writeln('## Recent logs (Kotlin/native)');
  _writeLogLines(buffer, native['logs']);
  final nativeLog = native['nativeLogcat'];
  if (nativeLog is List && nativeLog.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('### native logcat (SylvakruUsbExclusive)');
    _writeLogLines(buffer, nativeLog);
  }

  buffer.writeln();
  buffer.writeln('## Recent logs (Dart)');
  final dartLogs = logger.tailContaining('usb', max: 200);
  if (dartLogs.isEmpty) {
    buffer.writeln('(none)');
  } else {
    for (final l in dartLogs) {
      buffer.writeln(l);
    }
  }

  return buffer.toString();
}

void _writeListSection(StringBuffer buffer, Object? value) {
  if (value is List && value.isNotEmpty) {
    for (final item in value) {
      buffer.writeln('- $item');
    }
  } else {
    buffer.writeln('- none');
  }
}

void _writeDiagnosticsSnapshot(StringBuffer buffer, Object? value) {
  if (value is! Map || value.isEmpty) {
    buffer.writeln('- none');
    return;
  }
  for (final entry in value.entries) {
    final key = entry.key.toString();
    final item = entry.value;
    if (item is Map) {
      buffer.writeln('### $key');
      _writeDiagnosticsSnapshot(buffer, item);
    } else if (item is List) {
      buffer.writeln('### $key');
      _writeListSection(buffer, item);
    } else {
      buffer.writeln('- $key=$item');
    }
  }
}

void _writeLogLines(StringBuffer buffer, Object? value) {
  if (value is List && value.isNotEmpty) {
    for (final line in value) {
      buffer.writeln(line.toString());
    }
  } else {
    buffer.writeln('(none)');
  }
}

String _formatTimestamp(Object? millis) {
  final ms = _asInt(millis);
  if (ms == null || ms == 0) {
    return DateTime.now().toString();
  }
  return DateTime.fromMillisecondsSinceEpoch(ms).toString();
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

Duration? _durationFromMs(Object? value) {
  final milliseconds = _asInt(value);
  if (milliseconds == null) return null;
  return Duration(milliseconds: milliseconds.clamp(0, 60000));
}

List<int> _asIntList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map(_asInt).whereType<int>().toList(growable: false);
}

List<String> _asStringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList(growable: false);
}
