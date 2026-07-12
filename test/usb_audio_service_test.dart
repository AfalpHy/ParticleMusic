import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.afalphy.sylvakru/usb_audio');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    usbTransportTelemetryNotifier.value = UsbTransportTelemetry.inactive();
  });

  test(
    'refreshStatus maps USB device capabilities from platform channel',
    () async {
      final service = UsbAudioService(channel: channel, isAndroid: true);

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getStatus') {
          return {
            'supported': true,
            'androidSdk': 35,
            'activeDeviceId': 10,
            'preferredApplied': false,
            'preferredSampleRate': 96000,
            'preferredEncoding': 'pcm_24bit_packed',
            'preferredBitPerfect': true,
            'outputDeviceName': 'USB DAC',
            'outputSampleRate': 96000,
            'outputEncoding': 'pcm_24bit_packed',
            'manufacturerName': 'iBasso',
            'productName': 'DC04U',
            'vendorId': 0x0661,
            'productId': 0x0883,
            'message': 'USB audio device detected',
            'devices': [
              {
                'id': 10,
                'name': 'USB DAC',
                'type': 'usb_device',
                'address': 'bus-001',
                'sampleRates': [44100, 48000, 96000],
                'encodings': ['pcm_16bit', 'pcm_24bit_packed'],
                'channelCounts': [2],
                'supportedMixerSampleRates': [48000, 96000],
                'supportsBitPerfectMixer': true,
              },
            ],
          };
        }
        throw PlatformException(code: 'unexpected_method');
      });

      final status = await service.refreshStatus();

      expect(status.supported, isTrue);
      expect(status.androidSdk, 35);
      expect(status.activeDeviceId, 10);
      expect(status.preferredSampleRate, 96000);
      expect(status.preferredEncoding, 'pcm_24bit_packed');
      expect(status.preferredBitPerfect, isTrue);
      expect(status.outputDeviceName, 'USB DAC');
      expect(status.outputSampleRate, 96000);
      expect(status.outputEncoding, 'pcm_24bit_packed');
      expect(status.manufacturerName, 'iBasso');
      expect(status.productName, 'DC04U');
      expect(status.vendorId, 0x0661);
      expect(status.productId, 0x0883);
      expect(status.devices, hasLength(1));
      expect(status.devices.single.name, 'USB DAC');
      expect(status.devices.single.sampleRates, [44100, 48000, 96000]);
      expect(status.devices.single.supportsBitPerfectMixer, isTrue);
      expect(usbAudioStatusNotifier.value, status);
    },
  );

  test(
    'applyPreferredOutput requests requested sample rate and device id',
    () async {
      final service = UsbAudioService(channel: channel, isAndroid: true);
      Object? receivedArguments;

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'applyPreferredOutput') {
          receivedArguments = call.arguments;
          return {
            'supported': true,
            'androidSdk': 35,
            'activeDeviceId': 10,
            'preferredApplied': true,
            'outputSampleRate': 96000,
            'message': 'Applied preferred USB mixer attributes',
            'devices': const [],
          };
        }
        throw PlatformException(code: 'unexpected_method');
      });

      final status = await service.applyPreferredOutput(
        deviceId: 10,
        sampleRate: 96000,
      );

      expect(receivedArguments, {
        'deviceId': 10,
        'sampleRate': 96000,
        'encoding': 'pcm_24bit_packed',
        'bitPerfect': true,
      });
      expect(status.preferredApplied, isTrue);
      expect(status.message, 'Applied preferred USB mixer attributes');
    },
  );

  test('native USB added event updates status and event notifier', () async {
    UsbAudioService(channel: channel, isAndroid: true);

    final eventStatus = {
      'supported': true,
      'androidSdk': 35,
      'activeDeviceId': 18,
      'preferredApplied': false,
      'preferredSampleRate': null,
      'preferredEncoding': null,
      'preferredBitPerfect': false,
      'outputDeviceName': 'USB DAC',
      'outputSampleRate': 48000,
      'outputEncoding': 'pcm_16bit',
      'message': 'USB audio device detected.',
      'devices': [
        {
          'id': 18,
          'name': 'USB DAC',
          'type': 'usb_device',
          'address': 'dac-18',
          'sampleRates': [44100, 48000, 96000],
          'encodings': ['pcm_16bit', 'pcm_24bit_packed'],
          'channelCounts': [2],
          'supportedMixerSampleRates': [44100, 48000, 96000],
          'supportsBitPerfectMixer': true,
        },
      ],
    };

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onUsbAudioDeviceEvent', {
          'type': 'added',
          'deviceId': 18,
          'status': eventStatus,
        }),
      ),
      (_) {},
    );

    final event = usbAudioEventNotifier.value;
    expect(event, isNotNull);
    expect(event!.type, UsbAudioDeviceEventType.added);
    expect(event.deviceId, 18);
    expect(event.status.supported, isTrue);
    expect(event.status.devices.single.name, 'USB DAC');
    expect(usbAudioStatusNotifier.value.activeDeviceId, 18);
  });

  test('probeExclusiveAccess maps native USB claim result', () async {
    final service = UsbAudioService(channel: channel, isAndroid: true);

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'probeExclusiveAccess') {
        return {
          'supported': true,
          'permissionGranted': true,
          'deviceName': 'USB DAC',
          'deviceId': 21,
          'audioInterfaceCount': 2,
          'claimedInterfaceCount': 1,
          'rawDescriptorLength': 257,
          'message': 'USB Audio interface can be claimed.',
        };
      }
      throw PlatformException(code: 'unexpected_method');
    });

    final result = await service.probeExclusiveAccess();

    expect(result.supported, isTrue);
    expect(result.permissionGranted, isTrue);
    expect(result.deviceName, 'USB DAC');
    expect(result.deviceId, 21);
    expect(result.audioInterfaceCount, 2);
    expect(result.claimedInterfaceCount, 1);
    expect(result.interfaceClaimed, isTrue);
    expect(result.rawDescriptorLength, 257);
  });

  test(
    'getExclusiveCapabilities maps native exclusive USB capabilities',
    () async {
      final service = UsbAudioService(channel: channel, isAndroid: true);

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getExclusiveCapabilities') {
          return {
            'available': true,
            'permissionGranted': true,
            'deviceName': 'iBasso Macaron',
            'deviceId': 31,
            'interfaceNumber': 1,
            'alternateSetting': 1,
            'endpointAddress': 1,
            'maxPacketSize': 196,
            'sampleRates': [44100, 48000, 96000],
            'bitDepths': [16, 24, 32],
            'channelCounts': [2],
            'message': 'USB exclusive endpoint is available.',
          };
        }
        throw PlatformException(code: 'unexpected_method');
      });

      final capability = await service.getExclusiveCapabilities();

      expect(capability.available, isTrue);
      expect(capability.permissionGranted, isTrue);
      expect(capability.deviceName, 'iBasso Macaron');
      expect(capability.deviceId, 31);
      expect(capability.interfaceNumber, 1);
      expect(capability.alternateSetting, 1);
      expect(capability.endpointAddress, 1);
      expect(capability.maxPacketSize, 196);
      expect(capability.sampleRates, [44100, 48000, 96000]);
      expect(capability.bitDepths, [16, 24, 32]);
      expect(capability.channelCounts, [2]);
    },
  );

  test(
    'startExclusivePlayback sends playback request to native layer',
    () async {
      final service = UsbAudioService(channel: channel, isAndroid: true);
      Object? receivedArguments;

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'startExclusivePlayback') {
          receivedArguments = call.arguments;
          return {
            'playbackId': 'load-7',
            'active': true,
            'playing': true,
            'positionMs': 0,
            'durationMs': 180000,
            'sampleRate': 44100,
            'bitDepth': 24,
            'format': 'flac',
            'hardwareVolumeActive': true,
            'digitalVolumeActive': false,
            'message': 'USB exclusive playback started.',
          };
        }
        throw PlatformException(code: 'unexpected_method');
      });

      final state = await service.startExclusivePlayback(
        const UsbExclusivePlaybackRequest(
          playbackId: 'load-7',
          filePath: '/music/test.flac',
          title: 'Test',
          sourceFormat: 'flac',
          sampleRate: 44100,
          bitDepth: 24,
          volumeGain: 0.5,
          volumeMode: 'auto',
          dsdGainCompensationDb: 6,
          smoothVolumeHandoff: false,
          targetBufferMs: 320,
          startPaused: false,
        ),
      );

      expect(receivedArguments, {
        'playbackId': 'load-7',
        'filePath': '/music/test.flac',
        'title': 'Test',
        'sourceFormat': 'flac',
        'sampleRate': 44100,
        'bitDepth': 24,
        'dsdMode': null,
        'volumeGainQ16': 32768,
        'volumeMode': 'auto',
        'dsdGainCompensationDb': 6,
        'smoothHandoff': false,
        'targetBufferMs': 320,
        'startPaused': false,
        'streaming': false,
        'totalBytes': null,
      });
      expect(state.active, isTrue);
      expect(state.playbackId, 'load-7');
      expect(state.playing, isTrue);
      expect(state.position, Duration.zero);
      expect(state.duration, const Duration(minutes: 3));
      expect(state.sampleRate, 44100);
      expect(state.bitDepth, 24);
      expect(state.format, 'flac');
      expect(state.hardwareVolumeActive, isTrue);
      expect(state.digitalVolumeActive, isFalse);
      expect(usbExclusivePlaybackStateNotifier.value, state);
    },
  );

  test(
    'transport health reflects current level instead of latched history',
    () {
      final telemetry = UsbTransportTelemetry.fromMap({
        'active': true,
        'bufferLevelMs': 196,
        'minimumBufferLevelMs': 0,
        'targetBufferMs': 200,
        'underrunCount': 1,
        'lastUnderrunAtMs': 1000,
        'updatedAtMs': 4000,
      });

      expect(
        telemetry.health(playing: true, targetMs: 200),
        UsbTransportHealth.stable,
      );
    },
  );

  test('transport health reports only a recent underrun', () {
    final telemetry = UsbTransportTelemetry.fromMap({
      'active': true,
      'bufferLevelMs': 196,
      'targetBufferMs': 200,
      'underrunCount': 1,
      'lastUnderrunAtMs': 3000,
      'updatedAtMs': 4000,
    });

    expect(
      telemetry.health(playing: true, targetMs: 200),
      UsbTransportHealth.underrun,
    );
  });

  test('setExclusiveTargetBufferMs updates native exclusive buffer', () async {
    final service = UsbAudioService(channel: channel, isAndroid: true);
    Object? receivedArguments;

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setExclusiveTargetBufferMs') {
        receivedArguments = call.arguments;
        return null;
      }
      throw PlatformException(code: 'unexpected_method');
    });

    await service.setExclusiveTargetBufferMs(2400);

    expect(receivedArguments, {'targetBufferMs': 1000});
  });

  test('setExclusiveVolume sends gain and control mode', () async {
    final service = UsbAudioService(channel: channel, isAndroid: true);
    Object? receivedArguments;

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setExclusiveVolume') {
        receivedArguments = call.arguments;
        return null;
      }
      throw PlatformException(code: 'unexpected_method');
    });

    await service.setExclusiveVolume(
      gain: 0.5,
      mode: 'dac',
      dsdGainCompensationDb: -6,
      smoothHandoff: false,
    );

    expect(receivedArguments, {
      'gainQ16': 32768,
      'mode': 'dac',
      'dsdGainCompensationDb': -6,
      'smoothHandoff': false,
    });
  });

  test('native exclusive state event updates playback notifier', () async {
    UsbAudioService(channel: channel, isAndroid: true);

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onUsbExclusiveStateChanged', {
          'active': true,
          'playing': false,
          'positionMs': 42000,
          'durationMs': 240000,
          'sampleRate': 48000,
          'bitDepth': 24,
          'format': 'flac',
          'message': 'Paused.',
        }),
      ),
      (_) {},
    );

    final state = usbExclusivePlaybackStateNotifier.value;
    expect(state.active, isTrue);
    expect(state.playing, isFalse);
    expect(state.position, const Duration(seconds: 42));
    expect(state.duration, const Duration(minutes: 4));
    expect(state.sampleRate, 48000);
    expect(state.bitDepth, 24);
  });

  test('ignores an exclusive callback from an older playback', () async {
    final service = UsbAudioService(channel: channel, isAndroid: true);
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'startExclusivePlayback') {
        return {
          'playbackId': 'load-8',
          'active': true,
          'playing': true,
          'positionMs': 1000,
        };
      }
      throw PlatformException(code: 'unexpected_method');
    });
    await service.startExclusivePlayback(
      const UsbExclusivePlaybackRequest(
        playbackId: 'load-8',
        filePath: '/music/current.flac',
        title: 'Current',
        sourceFormat: 'flac',
        sampleRate: 48000,
        bitDepth: 24,
        volumeGain: 1,
        volumeMode: 'raw',
        targetBufferMs: 200,
        startPaused: false,
      ),
    );

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onUsbExclusiveStateChanged', {
          'playbackId': 'load-7',
          'active': false,
          'playing': false,
          'positionMs': 0,
          'message': 'USB exclusive playback completed.',
        }),
      ),
      (_) {},
    );

    expect(usbExclusivePlaybackStateNotifier.value.playbackId, 'load-8');
    expect(usbExclusivePlaybackStateNotifier.value.active, isTrue);
    expect(
      usbExclusivePlaybackStateNotifier.value.position,
      const Duration(seconds: 1),
    );
  });

  test('native transport telemetry event updates transport notifier', () async {
    UsbAudioService(channel: channel, isAndroid: true);

    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onUsbTransportTelemetryChanged', {
          'active': true,
          'bufferLevelMs': 184,
          'minimumBufferLevelMs': 120,
          'targetBufferMs': 200,
          'isoPacketCount': 4096,
          'pendingUrbs': 7,
          'underrunCount': 1,
          'updatedAtMs': 123456,
        }),
      ),
      (_) {},
    );

    final telemetry = usbTransportTelemetryNotifier.value;
    expect(telemetry.active, isTrue);
    expect(telemetry.bufferLevel, const Duration(milliseconds: 184));
    expect(telemetry.minimumBufferLevel, const Duration(milliseconds: 120));
    expect(telemetry.targetBuffer, const Duration(milliseconds: 200));
    expect(telemetry.isoPacketCount, 4096);
    expect(telemetry.pendingUrbs, 7);
    expect(telemetry.underrunCount, 1);
    expect(telemetry.updatedAtMs, 123456);
  });

  test(
    'getDiagnosticsReport assembles native data into a text report',
    () async {
      final service = UsbAudioService(channel: channel, isAndroid: true);

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getUsbDiagnosticsReport') {
          return {
            'generatedAtMs': 1751414400000,
            'androidSdk': 34,
            'androidRelease': '14',
            'manufacturer': 'Pixel',
            'model': 'Test',
            'permissionGranted': true,
            'device': {
              'vendorIdHex': '0x2972',
              'productIdHex': '0x0047',
              'manufacturerName': 'FiiO',
              'productName': 'FiiO KA13',
              'deviceClass': 0,
              'deviceSubclass': 0,
              'interfaceCount': 4,
              'audioInterfaceCount': 2,
              'serialTail': '****9F2A',
            },
            'diagnostics': {
              'available': true,
              'rawDescriptorLength': 32,
              'rawDescriptorsHex': '0000: 12 01 00 02',
              'streamingFormats': ['StreamingFormatInfo(alt=1)'],
              'outputCandidates': ['alt=1/max=294/bits=32'],
              'clockSourceId': 41,
              'session': {
                'id': 'usb-session-42',
                'input': {
                  'sourceFormat': 'dsf',
                  'mode': 'native',
                  'sampleRate': 176400,
                  'channels': 2,
                  'bitDepth': 32,
                },
                'outputSelections': [
                  {'sampleRate': 176400, 'selected': 'alt=2/max=768/bits=32'},
                ],
                'clock': {
                  'protocol': 'uac2',
                  'setCurResult': 4,
                  'readBack': 176400,
                },
                'feedback': {
                  'actualFrames': 22.05,
                  'nominalFrames': 22.05,
                  'ignoredCount': 0,
                },
                'transport': {
                  'submittedBytes': 1411200,
                  'pendingUrbs': 7,
                  'underrunCount': 0,
                },
              },
              'hardwareVolume': {
                'protocol': 'uac2',
                'controlInterface': 0,
                'featureUnits': ['unit=7/channel=0/volume=read-write'],
              },
            },
            'lastProbe': {'message': 'ok'},
            'systemStatus': {
              'devices': [
                {'id': 10, 'name': 'FiiO KA13'},
              ],
            },
            'nativeLogcat': ['01-01 00:00:00.000 I native line'],
            'logs': ['00:00:00.000 I/UsbExclusiveAudioEngine: open ok'],
          };
        }
        throw PlatformException(code: 'unexpected_method');
      });

      final report = await service.getDiagnosticsReport();

      expect(report, startsWith('Sylvakru USB Diagnostics Report v2'));
      expect(report, contains('App version'));
      expect(report, contains('0x2972 / 0x0047'));
      expect(report, contains('****9F2A'));
      expect(report, contains('## Raw descriptors (hex dump)'));
      expect(report, contains('0000: 12 01 00 02'));
      expect(report, contains('alt=1/max=294/bits=32'));
      expect(report, contains('UAC2 clock source id: 41'));
      expect(report, contains('## Preferences snapshot'));
      expect(report, contains('## Exclusive session'));
      expect(report, contains('usb-session-42'));
      expect(report, contains('alt=2/max=768/bits=32'));
      expect(report, contains('submittedBytes=1411200'));
      expect(report, contains('## Hardware volume probe'));
      expect(report, contains('unit=7/channel=0/volume=read-write'));
      expect(report, contains('open ok'));
      expect(report, contains('native line'));
    },
  );

  test('buildUsbDiagnosticsReport handles missing device data', () {
    final report = buildUsbDiagnosticsReport(const {}, platformSupported: true);

    expect(report, startsWith('Sylvakru USB Diagnostics Report v2'));
    expect(report, contains('No USB audio device detected.'));
    expect(report, contains('Descriptors unavailable.'));
  });
}
