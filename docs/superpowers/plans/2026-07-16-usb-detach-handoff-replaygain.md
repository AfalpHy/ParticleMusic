# USB 拔出安全交接与全路径 ReplayGain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** DAC 拔出后立即安全暂停并在共享输出恢复原位置和独立音量，同时让 ReplayGain 在独占与共享路径真实生效并独立展示。

**Architecture:** `UsbAudioService` 负责把设备移除转换为保留播放位置的 inactive 状态，`MyAudioHandler` 作为唯一交接协调点，串行完成暂停、共享音量恢复、媒体重开、ReplayGain 下发和 seek。ReplayGain 的选择值与实际应用结果由现有 `replay_gain.dart` 中的轻量状态统一发布，输出面板不再直接依赖原生独占字段。

**Tech Stack:** Flutter 3.44.5、Dart、media_kit `NativePlayer`、Flutter `MethodChannel`、ValueNotifier、flutter_test、Android USB Audio。

---

## 文件映射

- Modify: `lib/base/services/usb_audio_service.dart` — 保留位置的设备移除状态、连接状态判断。
- Modify: `lib/base/audio_handler.dart` — 设备移除监听、安全暂停交接、共享播放器打开顺序、共享/DAC 音量所有权、ReplayGain 实际状态发布。
- Modify: `lib/base/services/replay_gain.dart` — ReplayGain 应用阶段与输出路径状态。
- Modify: `lib/layer/audio_output_settings_layer.dart` — 无 DAC 时灰置 USB 媒体音量。
- Modify: `lib/base/widgets/audio_output_panel.dart` — 独立 ReplayGain 行并监听全路径状态。
- Modify: `lib/l10n/app_zh.arb` — ReplayGain 状态中文文案。
- Modify: `lib/l10n/app_en.arb` — ReplayGain 状态英文文案及占位符元数据。
- Modify: `test/usb_audio_service_test.dart` — 设备移除状态、连接判断和输出文案测试。
- Modify: `test/playback_restore_test.dart` — 最后可信独占位置和重复交接决策测试。
- Modify: `test/replay_gain_test.dart` — ReplayGain 应用状态测试。

执行前必须保留当前工作区已有修改。`lib/base/audio_handler.dart`、`lib/base/widgets/audio_output_panel.dart` 已有未提交格式变化，提交时必须用 `git add -p` 只暂存本计划新增的功能行；若无法拆分重叠 hunk，停止提交并先向用户说明，不能把原有修改一并提交。

### Task 1: 固定设备移除状态与最后可信位置规则

**Files:**
- Modify: `lib/base/services/usb_audio_service.dart:618-642`
- Modify: `lib/base/audio_handler.dart:49-70`
- Test: `test/usb_audio_service_test.dart`
- Test: `test/playback_restore_test.dart`

- [ ] **Step 1: 为设备移除写失败测试**

在 `test/usb_audio_service_test.dart` 增加：

```dart
test('设备移除立即发布保留最后位置的非活动状态', () {
  final service = UsbAudioService(channel: channel, isAndroid: true);
  usbExclusivePlaybackStateNotifier.value =
      UsbExclusivePlaybackState.fromMap({
        'playbackId': 'load-7',
        'active': true,
        'playing': false,
        'positionMs': 120000,
        'durationMs': 240000,
      });

  service.markExclusiveDeviceRemoved(
    position: const Duration(minutes: 2),
  );

  final state = usbExclusivePlaybackStateNotifier.value;
  expect(state.playbackId, 'load-7');
  expect(state.active, isFalse);
  expect(state.playing, isFalse);
  expect(state.position, const Duration(minutes: 2));
  expect(state.duration, const Duration(minutes: 4));
});

test('重复设备移除不重复发布独占状态', () {
  final service = UsbAudioService(channel: channel, isAndroid: true);
  usbExclusivePlaybackStateNotifier.value =
      UsbExclusivePlaybackState.inactive(
        playbackId: 'load-7',
        position: const Duration(minutes: 2),
      );
  final previous = usbExclusivePlaybackStateNotifier.value;

  service.markExclusiveDeviceRemoved(
    position: const Duration(minutes: 3),
  );

  expect(identical(usbExclusivePlaybackStateNotifier.value, previous), isTrue);
});
```

在 `test/playback_restore_test.dart` 增加：

```dart
test('中断状态为零或倒退时保留最后可信独占位置', () {
  expect(
    trustedUsbExclusivePosition(
      current: const Duration(minutes: 2),
      reported: Duration.zero,
      stateActive: false,
    ),
    const Duration(minutes: 2),
  );
  expect(
    trustedUsbExclusivePosition(
      current: const Duration(minutes: 2),
      reported: const Duration(seconds: 110),
      stateActive: false,
    ),
    const Duration(minutes: 2),
  );
});

test('活动会话允许用户向前或向后 seek', () {
  expect(
    trustedUsbExclusivePosition(
      current: const Duration(minutes: 2),
      reported: const Duration(seconds: 30),
      stateActive: true,
    ),
    const Duration(seconds: 30),
  );
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart test/playback_restore_test.dart
```

Expected: FAIL，提示 `markExclusiveDeviceRemoved`、`position` 参数或 `trustedUsbExclusivePosition` 尚不存在。

- [ ] **Step 3: 实现保留位置的 inactive 状态**

扩展 `UsbExclusivePlaybackState.inactive`，保持现有调用兼容：

```dart
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
    sourceBitDepth: null,
    decodedBitDepth: null,
    usbBitDepth: null,
    bitPerfect: null,
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
```

在 `UsbAudioService` 增加真实业务方法：

```dart
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
```

在 `lib/base/audio_handler.dart` 的现有纯函数区增加：

```dart
Duration trustedUsbExclusivePosition({
  required Duration current,
  required Duration reported,
  required bool stateActive,
}) {
  if (stateActive) return reported;
  return reported > current ? reported : current;
}
```

- [ ] **Step 4: 运行测试并确认通过**

Run:

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart test/playback_restore_test.dart
```

Expected: PASS。

- [ ] **Step 5: 创建独立提交**

```powershell
git add -p lib/base/services/usb_audio_service.dart lib/base/audio_handler.dart test/usb_audio_service_test.dart test/playback_restore_test.dart
git diff --cached --check
git diff --cached
git commit -m "fix(usb): 保留 DAC 拔出时的可信播放位置"
```

### Task 2: 实现拔出即暂停的单次共享输出交接

**Files:**
- Modify: `lib/base/audio_handler.dart:145-545`
- Test: `test/playback_restore_test.dart`

- [ ] **Step 1: 为交接启动条件写失败测试**

在 `test/playback_restore_test.dart` 增加：

```dart
test('只有意外失活且没有进行中的交接才启动共享回退', () {
  expect(
    shouldStartUsbOutputHandoff(
      wasActive: true,
      intentionalStop: false,
      handoffInProgress: false,
      completed: false,
    ),
    isTrue,
  );
  expect(
    shouldStartUsbOutputHandoff(
      wasActive: true,
      intentionalStop: true,
      handoffInProgress: false,
      completed: false,
    ),
    isFalse,
  );
  expect(
    shouldStartUsbOutputHandoff(
      wasActive: true,
      intentionalStop: false,
      handoffInProgress: true,
      completed: false,
    ),
    isFalse,
  );
  expect(
    shouldStartUsbOutputHandoff(
      wasActive: true,
      intentionalStop: false,
      handoffInProgress: false,
      completed: true,
    ),
    isFalse,
  );
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/playback_restore_test.dart
```

Expected: FAIL，提示 `shouldStartUsbOutputHandoff` 不存在。

- [ ] **Step 3: 增加交接决策与事件监听**

在纯函数区增加：

```dart
bool shouldStartUsbOutputHandoff({
  required bool wasActive,
  required bool intentionalStop,
  required bool handoffInProgress,
  required bool completed,
}) {
  return wasActive &&
      !intentionalStop &&
      !handoffInProgress &&
      !completed;
}
```

在 `MyAudioHandler` 增加状态：

```dart
bool _usbOutputHandoffInProgress = false;
int? _usbOutputHandoffGeneration;
int? _usbAudioDeviceId;
```

构造函数注册现有事件通知：

```dart
usbAudioEventNotifier.addListener(_handleUsbAudioEvent);
```

增加处理函数。先把播放语义切为暂停，再发布 inactive，保证状态监听不会自动续播：

```dart
void _handleUsbAudioEvent() {
  final event = usbAudioEventNotifier.value;
  if (event?.type != UsbAudioDeviceEventType.removed ||
      event?.deviceId != _usbAudioDeviceId ||
      !_usbExclusiveActive) {
    return;
  }
  final position = _usbExclusivePosition;
  updateIsPlaying(false);
  updatePlaybackState(postion: position);
  usbAudioService.markExclusiveDeviceRemoved(position: position);
}
```

- [ ] **Step 4: 统一 inactive 与 removed 的交接入口**

修改 `_handleUsbExclusiveState`，用以下代码替换该方法从读取 `state` 到 `_publishAndroidPlaybackInfo()` 的开头部分：

```dart
final state = usbExclusivePlaybackStateNotifier.value;
final wasActive = _usbExclusiveActive;
final interruptedPosition = trustedUsbExclusivePosition(
  current: _usbExclusivePosition,
  reported: state.position,
  stateActive: state.active,
);
_usbExclusivePosition = interruptedPosition;
_usbExclusiveActive = state.active;

if (wasActive && !state.active) {
  _cancelVolumeRamp();
  _cancelOutputGainRamp();
  _restoreSharedVolume();
}
_publishAndroidPlaybackInfo();
```

不要修改该方法中 `if (state.active)` 和 `if (wasActive && state.message?.contains('completed') == true)` 两个分支；将当前意外中断的 `else if (wasActive && !_intentionalExclusiveStop)` 分支完整替换为：

```dart
else if (shouldStartUsbOutputHandoff(
  wasActive: wasActive,
  intentionalStop: _intentionalExclusiveStop,
  handoffInProgress: _usbOutputHandoffInProgress,
  completed: false,
)) {
  logger.output(
    "usb exclusive interrupted -> safe system output handoff:${state.message}",
  );
  debugPrint(
    "usb exclusive interrupted -> safe system output handoff:${state.message}",
  );
  unawaited(
    _handoffToSystemOutputAfterExclusiveInterrupt(interruptedPosition),
  );
}
```

实现单次交接。这里不调用 `load()`，避免位置归零和重新尝试已拔出的 DAC：

```dart
Future<void> _handoffToSystemOutputAfterExclusiveInterrupt(
  Duration position,
) async {
  if (_usbOutputHandoffInProgress) return;
  final currentSong = currentSongNotifier.value;
  if (currentSong == null) return;

  final generation = _loadGeneration;
  _usbOutputHandoffInProgress = true;
  _usbOutputHandoffGeneration = generation;
  updateIsPlaying(false);
  updatePlaybackState(postion: position);
  try {
    await _applyUsbOutputForSong(currentSong);
    if (generation != _loadGeneration) return;
    await _openPlayerMedia(
      currentSong,
      startPosition: position,
      playAfterOpen: false,
    );
    if (generation != _loadGeneration) return;
    _positionController.add(position);
    updatePlaybackState(postion: position);
  } catch (error) {
    logger.output("usb exclusive interrupt handoff failed:$error");
    debugPrint("usb exclusive interrupt handoff failed:$error");
  } finally {
    if (_usbOutputHandoffGeneration == generation) {
      _usbOutputHandoffInProgress = false;
      _usbOutputHandoffGeneration = null;
    }
  }
}
```

- [ ] **Step 5: 让共享媒体在出声前完成增益和 seek**

先从 `_restoreSharedVolume` 删除下面这一行，避免媒体打开前发布一次无法验证的共享 ReplayGain：

```dart
unawaited(_applySharedReplayGain(_perceptualVolumeGain(volume)));
```

把 `_openPlayerMedia` 签名改为：

```dart
Future<void> _openPlayerMedia(
  MyAudioMetadata currentSong, {
  Duration startPosition = Duration.zero,
  bool? playAfterOpen,
}) async {
  final shouldPlay = playAfterOpen ?? isPlayingNotifier.value;
  if (currentSong.cacheExist) {
    await _player.open(Media(currentSong.cachePath!), play: false);
  } else {
    String? resource;
    bool needHeader = false;
    switch (currentSong.sourceType) {
      case .webdav:
        final tmpPath = await convertToRealPathIfNeed(currentSong.path!);
        if (tmpPath == null) {
          needHeader = true;
        } else {
          resource = tmpPath;
        }
        break;
      case .subsonic:
        currentSong.path ??= subsonicClient!.getStreamUrl(currentSong.id);
        break;
      case .navidrome:
        currentSong.path ??= navidromeClient!.getStreamUrl(currentSong.id);
        break;
      case .emby:
        currentSong.path ??= embyClient!.audioUrl(currentSong.id);
        break;
      default:
        break;
    }
    resource ??= currentSong.path!;
    await _player.open(
      Media(resource, httpHeaders: needHeader ? webdavClient?.headers : null),
      play: false,
    );
  }

  final sharedGain = _perceptualVolumeGain(_sharedUserVolume);
  _player.setVolume(sharedGain * 100);
  await _applySharedReplayGain(sharedGain);
  if (startPosition > Duration.zero) {
    await _player.seek(startPosition);
  }
  if (shouldPlay) {
    await _player.play();
  }
}
```

删除方法入口处原有的“打开前 `_applySharedReplayGain`”，并用新交接方法替换 `_resumeOnSystemOutputAfterExclusiveInterrupt`。

- [ ] **Step 6: 运行测试、格式化并提交**

```powershell
F:\software\flutter_3.44.5\bin\dart.bat format lib/base/audio_handler.dart test/playback_restore_test.dart
F:\software\flutter_3.44.5\bin\flutter.bat test test/playback_restore_test.dart test/usb_audio_service_test.dart
git add -p lib/base/audio_handler.dart test/playback_restore_test.dart
git diff --cached --check
git diff --cached
git commit -m "fix(usb): DAC 拔出后安全暂停并恢复播放位置"
```

Expected: 测试 PASS；暂存差异不包含执行前已有的无关格式变化。

### Task 3: 恢复共享音量并灰置无 DAC 的 USB 音量控件

**Files:**
- Modify: `lib/base/services/usb_audio_service.dart:812-900`
- Modify: `lib/base/audio_handler.dart:315-353`
- Modify: `lib/layer/audio_output_settings_layer.dart:955-1002`
- Test: `test/usb_audio_service_test.dart`
- Test: `test/usb_audio_preferences_test.dart`

- [ ] **Step 1: 为连接判断写失败测试**

在 `test/usb_audio_service_test.dart` 增加：

```dart
test('只有状态中仍存在 USB 设备时允许控制 DAC 音量', () {
  final connected = UsbAudioStatus.fromMap({
    'supported': true,
    'activeDeviceId': 18,
    'devices': [
      {'id': 18, 'name': 'USB DAC', 'type': 'usb_device'},
    ],
  });
  final removed = UsbAudioStatus.fromMap({
    'supported': true,
    'activeDeviceId': null,
    'devices': const [],
  });

  expect(connected.hasConnectedUsbAudioDevice, isTrue);
  expect(removed.hasConnectedUsbAudioDevice, isFalse);
});
```

- [ ] **Step 2: 运行测试并确认失败**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart
```

Expected: FAIL，提示 `hasConnectedUsbAudioDevice` 不存在。

- [ ] **Step 3: 增加连接判断并保留最后设备音量键**

在 `UsbAudioStatus` 增加：

```dart
bool get hasConnectedUsbAudioDevice {
  if (devices.isNotEmpty) return true;
  return activeDeviceId != null && vendorId != null && productId != null;
}
```

修改 `_handleUsbAudioStatus`，设备移除时不把 `_usbVolumeDeviceKey` 清成空设备默认值，也不覆盖当前 DAC 记忆音量：

```dart
void _handleUsbAudioStatus() {
  final status = usbAudioStatusNotifier.value;
  if (status.activeDeviceId != null) {
    _usbAudioDeviceId = status.activeDeviceId;
  }
  final deviceKey = usbExclusiveVolumeDeviceKey(
    status.vendorId,
    status.productId,
  );
  if (deviceKey != null) {
    _usbVolumeDeviceKey = deviceKey;
  }
  if (!_usbExclusiveActive &&
      status.hasConnectedUsbAudioDevice &&
      _usbVolumeDeviceKey != null) {
    usbExclusiveVolumeNotifier.value =
        usbAudioPreferences.volumeForDevice(_usbVolumeDeviceKey);
  }
}
```

- [ ] **Step 4: 无 DAC 时灰置 Slider**

将 `_mediaVolumeTile` 完整替换为以下实现，只增加状态监听、透明度和禁用回调，不改变原有标题、百分比和 SliderTheme：

```dart
Widget _mediaVolumeTile() {
  return ListenableBuilder(
    listenable: Listenable.merge([
      usbAudioStatusNotifier,
      usbExclusiveVolumeNotifier,
    ]),
    builder: (context, _) {
      final volume = usbExclusiveVolumeNotifier.value;
      final enabled =
          usbAudioStatusNotifier.value.hasConnectedUsbAudioDevice;
      final percent = (volume.clamp(0.0, 1.0) * 100).round();
      final sliderValue = volume.clamp(0.0, 1.0);
      return Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _l10n.mediaVolume,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: textColor.value.withAlpha(180),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: _sliderThemeData(context),
                child: Slider(
                  value: sliderValue,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  label: '$percent%',
                  onChanged: enabled
                      ? (next) {
                          usbExclusiveVolumeNotifier.value = next;
                          _setUsbExclusiveVolumeIfReady(next);
                        }
                      : null,
                  onChangeEnd: enabled ? (_) => setting.save() : null,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 5: 运行音量相关测试并提交**

```powershell
F:\software\flutter_3.44.5\bin\dart.bat format lib/base/services/usb_audio_service.dart lib/base/audio_handler.dart lib/layer/audio_output_settings_layer.dart test/usb_audio_service_test.dart
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart test/usb_audio_preferences_test.dart
git add -p lib/base/services/usb_audio_service.dart lib/base/audio_handler.dart lib/layer/audio_output_settings_layer.dart test/usb_audio_service_test.dart
git diff --cached --check
git diff --cached
git commit -m "fix(usb): 分离共享输出与 DAC 设备音量"
```

Expected: 测试 PASS；无 DAC 状态不会写入空设备音量键。

### Task 4: 建立全路径 ReplayGain 实际应用状态

**Files:**
- Modify: `lib/base/services/replay_gain.dart`
- Modify: `lib/base/audio_handler.dart:271-313, 1681-1740`
- Test: `test/replay_gain_test.dart`

- [ ] **Step 1: 为 ReplayGain 状态写失败测试**

在 `test/replay_gain_test.dart` 增加：

```dart
test('ReplayGain 状态区分关闭、无标签、等待、成功和失败', () {
  expect(
    ReplayGainPlaybackState.off().phase,
    ReplayGainApplyPhase.off,
  );
  expect(
    ReplayGainPlaybackState.noTag().phase,
    ReplayGainApplyPhase.noTag,
  );
  final pending = ReplayGainPlaybackState.pending(
    selectedDb: -6,
    path: ReplayGainOutputPath.sharedDigital,
    generation: 3,
  );
  final applied = pending.applied(actualDb: -5.5);
  final failed = pending.failed();

  expect(pending.phase, ReplayGainApplyPhase.pending);
  expect(applied.phase, ReplayGainApplyPhase.applied);
  expect(applied.actualDb, -5.5);
  expect(failed.phase, ReplayGainApplyPhase.failed);
});
```

- [ ] **Step 2: 运行测试并确认失败**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/replay_gain_test.dart
```

Expected: FAIL，提示新的 ReplayGain 状态类型不存在。

- [ ] **Step 3: 在现有 ReplayGain 服务定义轻量状态**

在 `replay_gain.dart` 增加 `flutter/foundation.dart` 导入，并定义：

```dart
enum ReplayGainApplyPhase { off, noTag, pending, applied, failed }

enum ReplayGainOutputPath { none, sharedDigital, usbDigital, usbHardware }

@immutable
class ReplayGainPlaybackState {
  final ReplayGainApplyPhase phase;
  final ReplayGainOutputPath path;
  final double selectedDb;
  final double? actualDb;
  final int generation;

  const ReplayGainPlaybackState({
    required this.phase,
    required this.path,
    required this.selectedDb,
    required this.actualDb,
    required this.generation,
  });

  factory ReplayGainPlaybackState.off() =>
      const ReplayGainPlaybackState(
        phase: ReplayGainApplyPhase.off,
        path: ReplayGainOutputPath.none,
        selectedDb: 0,
        actualDb: 0,
        generation: 0,
      );

  factory ReplayGainPlaybackState.noTag() =>
      const ReplayGainPlaybackState(
        phase: ReplayGainApplyPhase.noTag,
        path: ReplayGainOutputPath.none,
        selectedDb: 0,
        actualDb: 0,
        generation: 0,
      );

  factory ReplayGainPlaybackState.pending({
    required double selectedDb,
    required ReplayGainOutputPath path,
    required int generation,
  }) => ReplayGainPlaybackState(
    phase: ReplayGainApplyPhase.pending,
    path: path,
    selectedDb: selectedDb,
    actualDb: null,
    generation: generation,
  );

  ReplayGainPlaybackState applied({required double actualDb}) =>
      ReplayGainPlaybackState(
        phase: ReplayGainApplyPhase.applied,
        path: path,
        selectedDb: selectedDb,
        actualDb: actualDb,
        generation: generation,
      );

  ReplayGainPlaybackState failed() => ReplayGainPlaybackState(
    phase: ReplayGainApplyPhase.failed,
    path: path,
    selectedDb: selectedDb,
    actualDb: null,
    generation: generation,
  );
}

final replayGainPlaybackStateNotifier = ValueNotifier(
  ReplayGainPlaybackState.off(),
);
```

- [ ] **Step 4: 共享路径在播放器打开后发布真实结果**

在 `MyAudioHandler` 增加：

```dart
int _replayGainApplyGeneration = 0;

ReplayGainPlaybackState _pendingReplayGainState(
  ReplayGainOutputPath path,
  int generation,
) {
  final mode = usbAudioPreferences.replayGainModeNotifier.value;
  if (mode == ReplayGainMode.off) return ReplayGainPlaybackState.off();
  if (_currentReplayGain.source == null) {
    return ReplayGainPlaybackState.noTag();
  }
  return ReplayGainPlaybackState.pending(
    selectedDb: _currentReplayGain.gainDb,
    path: path,
    generation: generation,
  );
}
```

将 `_applySharedReplayGain` 改为先发布 pending、成功后发布实际 dB、失败后发布 failed；无论标签是否存在都必须写入 `volume-gain`，以清除上一首的旧增益：

```dart
Future<void> _applySharedReplayGain(
  double userLinearGain, {
  double maxIncreaseDb = _safeUsbVolumeIncreaseDb,
}) async {
  final generation = ++_replayGainApplyGeneration;
  final pending = _pendingReplayGainState(
    ReplayGainOutputPath.sharedDigital,
    generation,
  );
  replayGainPlaybackStateNotifier.value = pending;
  final transition = safeOutputGainTransition(
    appliedGain: _appliedOutputGain,
    userGain: userLinearGain,
    adjustmentDb: _effectiveReplayGainDb(userLinearGain),
    maxIncreaseDb: maxIncreaseDb,
  );
  _appliedOutputGain = transition.appliedGain;
  try {
    await (_player.platform as NativePlayer).setProperty(
      'volume-gain',
      transition.adjustmentDb.toStringAsFixed(3),
    );
    if (generation != _replayGainApplyGeneration || _usbExclusiveActive) {
      return;
    }
    replayGainPlaybackStateNotifier.value =
        pending.phase == ReplayGainApplyPhase.pending
        ? pending.applied(actualDb: transition.adjustmentDb)
        : pending;
    if (transition.needsRamp) {
      _scheduleOutputGainRamp(maxIncreaseDb);
    } else {
      _cancelOutputGainRamp();
    }
  } on Object catch (error) {
    if (generation == _replayGainApplyGeneration) {
      replayGainPlaybackStateNotifier.value =
          pending.phase == ReplayGainApplyPhase.pending
          ? pending.failed()
          : pending;
    }
    logger.output("replay gain apply failed:$error");
  }
}
```

- [ ] **Step 5: 独占路径从真实硬件/数字状态发布结果**

增加 `_publishExclusiveReplayGainState`，并在 `_handleUsbExclusiveState` 的 active 分支及 `_applyUsbExclusiveVolume` 完成后调用：

```dart
void _publishExclusiveReplayGainState(UsbExclusivePlaybackState state) {
  if (!state.active) return;
  final generation = ++_replayGainApplyGeneration;
  final path = state.hardwareVolumeActive
      ? ReplayGainOutputPath.usbHardware
      : state.digitalVolumeActive
      ? ReplayGainOutputPath.usbDigital
      : ReplayGainOutputPath.none;
  final pending = _pendingReplayGainState(path, generation);
  if (pending.phase != ReplayGainApplyPhase.pending) {
    replayGainPlaybackStateNotifier.value = pending;
    return;
  }
  if (path == ReplayGainOutputPath.none) {
    replayGainPlaybackStateNotifier.value = pending.failed();
    return;
  }
  replayGainPlaybackStateNotifier.value = pending.applied(
    actualDb: state.replayGainMilliDb / 1000,
  );
}
```

将 `_applyUsbExclusiveVolume` 完整替换为：

```dart
Future<void> _applyUsbExclusiveVolume(
  double digitalGain, {
  double maxIncreaseDb = _safeUsbVolumeIncreaseDb,
}) async {
  if (!_usbExclusiveActive) return;
  final isDsd = currentSongNotifier.value?.isDsd == true;
  final dsdCompensationDb = isDsd
      ? usbAudioPreferences.dsdGainCompensationNotifier.value
      : 0;
  final transition = safeOutputGainTransition(
    appliedGain: _appliedOutputGain,
    userGain: digitalGain,
    adjustmentDb:
        _effectiveReplayGainDb(digitalGain) + dsdCompensationDb,
    maxIncreaseDb: maxIncreaseDb,
  );
  _appliedOutputGain = transition.appliedGain;
  await usbAudioService.setExclusiveVolume(
    gain: digitalGain,
    replayGainDb: transition.adjustmentDb - dsdCompensationDb,
    mode: usbAudioPreferences.volumeControlModeNotifier.value.name,
    dsdGainCompensationDb: dsdCompensationDb,
    smoothHandoff: usbAudioPreferences.volumeSmoothHandoffNotifier.value,
  );
  if (_usbExclusiveActive) {
    _publishExclusiveReplayGainState(
      usbExclusivePlaybackStateNotifier.value,
    );
  }
  if (transition.needsRamp) {
    _scheduleOutputGainRamp(maxIncreaseDb);
  } else {
    _cancelOutputGainRamp();
  }
}
```

- [ ] **Step 6: 运行测试并提交**

```powershell
F:\software\flutter_3.44.5\bin\dart.bat format lib/base/services/replay_gain.dart lib/base/audio_handler.dart test/replay_gain_test.dart
F:\software\flutter_3.44.5\bin\flutter.bat test test/replay_gain_test.dart test/playback_restore_test.dart
git add -p lib/base/services/replay_gain.dart lib/base/audio_handler.dart test/replay_gain_test.dart
git diff --cached --check
git diff --cached
git commit -m "fix(audio): 统一独占与共享 ReplayGain 应用状态"
```

### Task 5: 将 ReplayGain 从 Bit-perfect 拆为独立信息行

**Files:**
- Modify: `lib/base/widgets/audio_output_panel.dart:516-658, 994-1035`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/usb_audio_service_test.dart`

- [ ] **Step 1: 增加中英文状态文案**

在中英文 ARB 增加相同键：

```json
// app_zh.arb
"replayGainApplying": "同步中",
"replayGainNotApplied": "未应用",
"replayGainNoTag": "无标签"
```

```json
// app_en.arb
"replayGainApplying": "Syncing",
"replayGainNotApplied": "Not applied",
"replayGainNoTag": "No tag"
```

- [ ] **Step 2: 为独立状态格式写失败测试**

在 `test/usb_audio_service_test.dart` 增加：

```dart
test('ReplayGain 输出文案使用实际应用值并区分状态', () {
  final l10n = AppLocalizationsZh();
  expect(
    formatReplayGainStatus(ReplayGainPlaybackState.off(), l10n),
    l10n.replayGainOff,
  );
  expect(
    formatReplayGainStatus(ReplayGainPlaybackState.noTag(), l10n),
    l10n.replayGainNoTag,
  );
  final applied = ReplayGainPlaybackState.pending(
    selectedDb: -8.4,
    path: ReplayGainOutputPath.sharedDigital,
    generation: 2,
  ).applied(actualDb: -8.4);
  expect(formatReplayGainStatus(applied, l10n), '-8.4 dB');
});
```

- [ ] **Step 3: 运行生成与测试并确认失败**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart
```

Expected: `gen-l10n` 成功；测试 FAIL，提示 `formatReplayGainStatus` 不存在。

- [ ] **Step 4: 实现状态格式并拆分 UI 行**

在 `audio_output_panel.dart` 导入 `replay_gain.dart`，增加：

```dart
String formatReplayGainStatus(
  ReplayGainPlaybackState state,
  AppLocalizations l10n,
) {
  return switch (state.phase) {
    ReplayGainApplyPhase.off => l10n.replayGainOff,
    ReplayGainApplyPhase.noTag => l10n.replayGainNoTag,
    ReplayGainApplyPhase.pending => l10n.replayGainApplying,
    ReplayGainApplyPhase.failed => l10n.replayGainNotApplied,
    ReplayGainApplyPhase.applied =>
      '${state.actualDb!.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '')} dB',
  };
}
```

将当前 `ValueListenableBuilder` 的以下开头：

```dart
return ValueListenableBuilder(
  valueListenable: usbAudioStatusNotifier,
  builder: (context, status, child) {
    final exclusive = usbExclusivePlaybackStateNotifier.value;
    final showPcmDepths = exclusive.active && exclusive.bitDepth != 1;
```

替换为：

```dart
return ListenableBuilder(
  listenable: Listenable.merge([
    usbAudioStatusNotifier,
    usbExclusivePlaybackStateNotifier,
    replayGainPlaybackStateNotifier,
  ]),
  builder: (context, child) {
    final status = usbAudioStatusNotifier.value;
    final exclusive = usbExclusivePlaybackStateNotifier.value;
    final replayGain = replayGainPlaybackStateNotifier.value;
    final showPcmDepths = exclusive.active && exclusive.bitDepth != 1;
```

替换范围只到 `showPcmDepths` 声明；其后的现有 `return Padding` widget 树继续直接位于 builder 中，不拆分新方法。

在信号输出 rows 中紧跟 `Bit-perfect` 增加：

```dart
_InfoRow(
  l10n.replayGain,
  formatReplayGainStatus(replayGain, l10n),
),
```

从 `_bitPerfectStatusLabel` 删除以下完整分支，其余分支不改：

```dart
if (exclusive.replayGainMilliDb != 0) {
  if (exclusive.hardwareVolumeActive || exclusive.digitalVolumeActive) {
    final gain = (exclusive.replayGainMilliDb / 1000)
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'\.?0+$'), '');
    return l10n.audioProcessingWithReplayGain(processing, gain);
  }
  return l10n.audioProcessingWithReplayGainNotApplied(processing);
}
```

不得改变颜色、间距、卡片、标题或其它页面视觉。

- [ ] **Step 5: 运行生成、测试并提交**

```powershell
F:\software\flutter_3.44.5\bin\dart.bat format lib/base/widgets/audio_output_panel.dart test/usb_audio_service_test.dart
F:\software\flutter_3.44.5\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart test/replay_gain_test.dart
git add -p lib/base/widgets/audio_output_panel.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb test/usb_audio_service_test.dart
git diff --cached --check
git diff --cached
git commit -m "feat(audio): 独立展示全路径 ReplayGain 状态"
```

Expected: 测试 PASS；提交不包含 generated plugin registrant 或执行前已有的面板格式改动。

### Task 6: 完整验证、真机检查与推送

**Files:**
- Verify only; do not add generated plugin registrant files.

- [ ] **Step 1: 检查工作区与提交范围**

```powershell
git status --short
git diff --check
git log --oneline -6
```

Expected: 本任务修改均已提交；执行前已有的 Kotlin、旧设计文档和各平台 generated plugin 文件仍保持原样未提交。

- [ ] **Step 2: 运行相关 Dart 测试**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/playback_restore_test.dart test/usb_audio_service_test.dart test/usb_audio_preferences_test.dart test/replay_gain_test.dart test/usb_volume_safety_test.dart test/android_remote_volume_test.dart
```

Expected: 全部 PASS。

- [ ] **Step 3: 运行本地化、静态分析和 Android 单元测试**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.5\bin\flutter.bat analyze
Set-Location android
.\gradlew.bat app:testDebugUnitTest
Set-Location ..
```

Expected: `gen-l10n` 和 Android 单元测试成功；`analyze` 无本任务新增错误。若仓库已有告警，记录完整数量和与本任务的关系，不得声称全绿。

- [ ] **Step 4: 构建 arm64 profile APK**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64
```

Expected: `build\app\outputs\flutter-apk\app-profile.apk` 构建成功；APK 不加入 Git。

- [ ] **Step 5: 真机验证安全交接**

按顺序人工验证并保留开发者日志：

1. 共享输出音量设为 20%，连接 Macaron，并把 DAC 音量设为不同值。
2. 播放 PCM 到约 2 分钟，拔出 DAC。
3. 确认立即暂停、输出状态变为非独占、进度仍约 2 分钟，手机扬声器不自动出声。
4. 手动点击播放，确认从原位置通过当前共享设备继续，音量使用先前 20%。
5. 暂停状态连接 DAC、播放后再次暂停并拔出，确认无需再点播放即可刷新状态。
6. 无 DAC 时打开 USB 设置，确认“当前媒体音量”保留数值但灰置不可拖动。
7. 播放带 ReplayGain 的 Navidrome 歌曲，分别验证共享输出和 USB 独占显示相同来源下的实际 dB。
8. 切换到无 ReplayGain 标签歌曲和关闭模式，确认分别显示“无标签”和“关闭”。

日志中不得出现同一次拔出触发两次 `_openPlayerMedia`、从零点短暂播放或重新尝试已移除 DAC。

- [ ] **Step 6: 推送当前开发分支**

```powershell
git status --short
git push fork usb-exclusive-volume-overlay-performance
git log --oneline fork/usb-exclusive-volume-overlay-performance..HEAD
```

Expected: 推送成功，最后一条命令无输出；现有非本任务脏文件仍未被提交。
