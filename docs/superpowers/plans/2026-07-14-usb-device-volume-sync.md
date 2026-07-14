# USB 设备独立音量与双向同步实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将普通媒体音量与 USB 独占音量分离，按 `VID:PID` 保存每台 DAC 的音量，并修复手机音量键、DAC 主动上报、ReplayGain 与 iBasso HID 重连之间的同步和安全边界。

**Architecture:** 保留现有 `volumeNotifier` 作为当前播放界面的音量显示，在 `MyAudioHandler` 内单独保存共享输出音量，并由 `UsbAudioPreferences` 持久化每台 DAC 的独占音量。手机按键走明确的 5%/20% 边界，DAC 事件直接成为事实来源且不反写；原生层用设备编号关联可信 iBasso 目标，使同设备 HID 重连可以安全续用、主动事件可以恢复已验证状态。

**Tech Stack:** Flutter 3.44.5、Dart、audio_service、Android Kotlin、JUnit4、Flutter Test。

---

### Task 1: 固化音量边界与设备音量持久化

**Files:**
- Modify: `lib/base/services/usb_audio_preferences.dart`
- Modify: `lib/base/audio_handler.dart`
- Modify: `lib/base/services/replay_gain.dart`
- Test: `test/usb_audio_preferences_test.dart`
- Test: `test/android_remote_volume_test.dart`
- Test: `test/replay_gain_test.dart`

- [ ] **Step 1: 为每台 DAC 音量写失败测试**

在 `test/usb_audio_preferences_test.dart` 增加：

```dart
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
    (usbAudioPreferences.toMap()['usbExclusiveDeviceVolumes'] as Map)['0661:0883'],
    0.25,
  );
});
```

- [ ] **Step 2: 为手机按键和 ReplayGain 边界写失败测试**

在 `test/android_remote_volume_test.dart` 将相对按键期望改为 `0.55/0.45`，并增加：

```dart
test('远程绝对音量降低立即生效而提高单次不超过百分之二十', () {
  expect(adjustedAbsoluteRemoteVolume(0.6, 20), 0.2);
  expect(adjustedAbsoluteRemoteVolume(0.2, 90), 0.4);
  expect(adjustedAbsoluteRemoteVolume(0.95, 100), 1);
});
```

在 `test/replay_gain_test.dart` 增加：

```dart
test('ReplayGain 可指定每步百分之二十的上升边界', () {
  final transition = safeOutputGainTransition(
    appliedGain: 0.2,
    userGain: 0.8,
    adjustmentDb: 0,
    maxIncrease: 0.2,
  );

  expect(transition.appliedGain, closeTo(0.4, 0.000001));
  expect(transition.needsRamp, isTrue);
});
```

- [ ] **Step 3: 运行测试确认失败**

Run:

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test\usb_audio_preferences_test.dart test\android_remote_volume_test.dart test\replay_gain_test.dart
```

Expected: 因 `volumeForDevice`、`setVolumeForDevice`、`adjustedAbsoluteRemoteVolume` 和 `maxIncrease` 尚不存在而失败。

- [ ] **Step 4: 实现最小纯逻辑**

在 `UsbAudioPreferences` 中加入 30% 默认值和按设备存取，键只接受四位十六进制 `VID:PID`，值限制到 `0..1`：

```dart
static const defaultExclusiveVolume = 0.3;
final Map<String, double> _exclusiveDeviceVolumes = {};

double volumeForDevice(String? key) =>
    key == null ? defaultExclusiveVolume :
    _exclusiveDeviceVolumes[key.toLowerCase()] ?? defaultExclusiveVolume;

void setVolumeForDevice(String? key, double volume) {
  if (key == null || !RegExp(r'^[0-9a-f]{4}:[0-9a-f]{4}$').hasMatch(key.toLowerCase())) {
    return;
  }
  _exclusiveDeviceVolumes[key.toLowerCase()] =
      volume.clamp(0.0, 1.0).toDouble();
}
```

`load()` 清空并读取 `usbExclusiveDeviceVolumes`，`toMap()` 写回其不可变副本。`adjustedRemoteVolume` 使用 `0.05`，新增 `adjustedAbsoluteRemoteVolume(current, index)`，下降直接返回目标、上升返回 `min(target, current + 0.20)`。`safeOutputGainTransition` 增加默认参数 `double maxIncrease = 0.02`，用它代替硬编码 `0.02`。

- [ ] **Step 5: 运行测试确认通过并提交**

Run:

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test\usb_audio_preferences_test.dart test\android_remote_volume_test.dart test\replay_gain_test.dart
git diff --check
git add lib/base/services/usb_audio_preferences.dart lib/base/services/replay_gain.dart test/usb_audio_preferences_test.dart test/android_remote_volume_test.dart test/replay_gain_test.dart
git add -p lib/base/audio_handler.dart
git commit -m "feat(usb): 添加设备音量记录与按键边界"
```

Expected: 三个测试文件全部通过；暂存的 `audio_handler.dart` 不包含用户原有格式化改动。

### Task 2: 分离共享音量与 USB 独占音量

**Files:**
- Modify: `lib/base/audio_handler.dart`
- Modify: `lib/layer/audio_output_settings_layer.dart`
- Test: `test/android_remote_volume_test.dart`
- Test: `test/usb_audio_preferences_test.dart`

- [ ] **Step 1: 为设备键和初始音量优先级写失败测试**

在 `test/usb_audio_preferences_test.dart` 增加：

```dart
test('USB 状态生成稳定 VID PID 音量键', () {
  expect(usbExclusiveVolumeDeviceKey(0x0661, 0x0883), '0661:0883');
  expect(usbExclusiveVolumeDeviceKey(null, 0x0883), isNull);
});
```

并验证没有设备记录时为 `0.3`、有记录时返回记录值。

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test\usb_audio_preferences_test.dart
```

Expected: `usbExclusiveVolumeDeviceKey` 尚不存在。

- [ ] **Step 3: 在现有音频处理器中实现两个音量域**

在 `audio_handler.dart` 顶层增加 `usbExclusiveVolumeNotifier` 和稳定键函数：

```dart
final usbExclusiveVolumeNotifier = ValueNotifier(
  UsbAudioPreferences.defaultExclusiveVolume,
);

String? usbExclusiveVolumeDeviceKey(int? vendorId, int? productId) {
  if (vendorId == null || productId == null) return null;
  return '${vendorId.toRadixString(16).padLeft(4, '0')}:'
      '${productId.toRadixString(16).padLeft(4, '0')}';
}
```

在 `MyAudioHandler` 中保留 `_sharedUserVolume`。进入独占前根据当前 `UsbAudioStatus.vendorId/productId` 读取设备音量，起播请求使用它；启动失败或退出独占时恢复 `_sharedUserVolume`。独占期间 `_applyUserVolume` 更新设备记录和 `usbExclusiveVolumeNotifier`，共享期间只更新 `_sharedUserVolume`；`savePlayState()` 始终写共享音量。

手机相对键直接应用 5%，绝对请求使用 `adjustedAbsoluteRemoteVolume`；这两条路径不进入 2% 用户斜坡，并把输出增益单步边界设为 20%。ReplayGain 元数据或模式变化使用每 100ms 20% 的输出增益边界，DSD 起播、路径切换和一般滑块继续使用原有 2% 安全边界。

DAC 主动事件直接更新 `_appliedUserVolume`、`volumeNotifier`、`usbExclusiveVolumeNotifier` 和设备记录，不调用 `_applyUsbExclusiveVolume`，从而不把旧值反写给设备。

- [ ] **Step 4: 让 USB 设置滑块只操作 USB 音量**

把 `_mediaVolumeTile()` 的监听源改为 `usbExclusiveVolumeNotifier`，`onChanged` 调用 `audioHandler.setUsbExclusiveVolume(next)`。该方法在独占活跃时立即写当前 DAC，在未播放时只保存当前连接设备的 USB 音量；普通播放页继续使用原有 `volumeNotifier`。

- [ ] **Step 5: 格式化、测试并提交**

Run:

```powershell
F:\software\flutter_3.44.5\bin\dart.bat format lib\base\services\usb_audio_preferences.dart lib\base\services\replay_gain.dart lib\base\audio_handler.dart lib\layer\audio_output_settings_layer.dart test\usb_audio_preferences_test.dart test\android_remote_volume_test.dart test\replay_gain_test.dart
F:\software\flutter_3.44.5\bin\flutter.bat test test\usb_audio_preferences_test.dart test\android_remote_volume_test.dart test\replay_gain_test.dart
git diff --check
git add lib/layer/audio_output_settings_layer.dart test/usb_audio_preferences_test.dart test/android_remote_volume_test.dart test/replay_gain_test.dart
git add -p lib/base/audio_handler.dart
git commit -m "feat(usb): 按设备分离独占音量"
```

Expected: 相关测试通过；共享播放状态文件仍保存共享音量，USB 设置滑块不再读取它。

### Task 3: 修复 iBasso HID 重连与主动上报验证状态

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

- [ ] **Step 1: 为可信目标设备关联写失败测试**

在 `UsbVolumeProtocolTest.kt` 增加：

```kotlin
@Test
fun keepsTrustedIbassoTargetOnlyForSameDevice() {
    val target = UsbVolumeTarget(baseRaw = 97, dsdRaw = 85)

    assertEquals(target, trustedIbassoTargetForDevice(target, 7, 7))
    assertNull(trustedIbassoTargetForDevice(target, 7, 8))
    assertNull(trustedIbassoTargetForDevice(null, 7, 7))
}
```

同时增加主动事件生成可信目标的测试：

```kotlin
@Test
fun unsolicitedIbassoEventBecomesTrustedTarget() {
    assertEquals(
        UsbVolumeTarget(baseRaw = 97, dsdRaw = 85),
        ibassoTargetFromEvent(baseRaw = 97, dsdCompensationDb = 6),
    )
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest"
cd ..
```

Expected: 两个纯函数尚不存在。

- [ ] **Step 3: 实现可信目标与主动事件同步**

在 `UsbVolumeProtocol.kt` 增加：

```kotlin
internal fun trustedIbassoTargetForDevice(
    target: UsbVolumeTarget?,
    targetDeviceId: Int?,
    deviceId: Int,
): UsbVolumeTarget? = target.takeIf { targetDeviceId == deviceId }

internal fun ibassoTargetFromEvent(
    baseRaw: Int,
    dsdCompensationDb: Int,
): UsbVolumeTarget = UsbVolumeTarget(
    baseRaw.coerceIn(0, 255),
    ibassoDsdVolume(baseRaw, dsdCompensationDb),
)
```

原生引擎增加 `ibassoLastAppliedDeviceId`。同一设备 HID 连接重建时使用可信目标；`closeIbassoVolumeControl(resetReaderHealth = false)` 保留目标和设备编号，永久关闭或切换设备时清除。写入并验证成功、write-only 成功或收到主动事件时更新目标设备编号。

处理主动事件时先调用 `afterVerifiedReadback()`，再设置 `hardwareVolumeActive = true`、更新 `ibassoLastAppliedTarget` 和 `ibassoLastAppliedDeviceId`，最后构建状态图，使 `hardwareVolumeReadbackVerified` 在事件发布时已经为真。

- [ ] **Step 4: 避免向 Android 暴露未验证硬件音量**

把 Dart 的 `shouldUseRemoteAndroidVolume` 条件改为：硬件路径必须同时满足 `hardwareVolumeActive && hardwareVolumeReadbackVerified`；PCM 数字音量仍可远程控制，1-bit DSD 数字路径仍拒绝。

- [ ] **Step 5: 运行原生和 Dart 测试并提交**

Run:

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest
cd ..
F:\software\flutter_3.44.5\bin\flutter.bat test test\android_remote_volume_test.dart test\usb_audio_service_test.dart
git diff --check
git add android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt test/android_remote_volume_test.dart
git add -p android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git add -p lib/base/audio_handler.dart
git commit -m "fix(usb): 保留 DAC 音量验证与主动同步"
```

Expected: Android 全部单元测试及两个 Dart 测试文件通过；暂存区不包含用户原有 `playbackId` 移位或格式化改动。

### Task 4: 全量验证、arm64 构建与真机复测

**Files:**
- Verify only: all files changed in Tasks 1-3

- [ ] **Step 1: 运行 Flutter 生成、分析和测试**

Run:

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.5\bin\flutter.bat analyze
F:\software\flutter_3.44.5\bin\flutter.bat test
```

Expected: `gen-l10n` 成功；`analyze` 不新增错误；测试全部通过。

- [ ] **Step 2: 运行 Android 测试并构建 arm64 Profile APK**

Run:

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest
cd ..
F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64
```

Expected: Android 测试通过，生成 arm64 Profile APK。

- [ ] **Step 3: 安装并人工验证三个播放来源**

连接设备后安装 Profile APK，分别播放本地文件、Navidrome `.part` 和下载完成缓存。验证：

```text
手机音量键：每次约 5%，绝对上升不超过 20%
DAC 旋钮：应用和 Android 音量立即跟随，不出现反向跳回
普通播放退出 USB 后：恢复原普通媒体音量
重新进入同一 DAC：恢复该 VID:PID 记录
DSD 切歌：无 register=0，无原始满幅回退
日志：不再连续出现 No trusted previous iBasso hardware volume
```

- [ ] **Step 4: 检查提交与推送**

Run:

```powershell
git status
git diff --check
git log -4 --oneline
git push fork usb-exclusive-volume-overlay-performance
```

Expected: 只有开始任务前已经存在的用户未提交修改；所有新提交已推送到 `fork/usb-exclusive-volume-overlay-performance`。
