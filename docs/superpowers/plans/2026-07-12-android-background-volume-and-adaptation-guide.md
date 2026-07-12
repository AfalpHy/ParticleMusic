# Android 后台音量键与通用适配手册 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Android 锁屏和后台物理音量键控制当前 USB DAC，并把 DAC 新厂商适配流程整理成可复用手册。

**Architecture:** USB 音量生效时由 audio_service 发布远程绝对音量 MediaSession，所有相对/绝对回调进入 `MyAudioHandler` 的单一音量入口；退出独占后恢复本地音量。删除 Activity 前台拦截，避免重复事件。

**Tech Stack:** Flutter audio_service 0.18.18、Android MediaSession/VolumeProviderCompat、Dart、Kotlin、Markdown。

---

## 文件映射

- 修改：`lib/base/audio_handler.dart`、`lib/base/services/usb_audio_service.dart`。
- 修改：`android/app/src/main/kotlin/com/afalphy/sylvakru/MainActivity.kt`。
- 测试：新建 `test/android_remote_volume_test.dart`，修改 `usb_audio_service_test.dart`。
- 文档：`docs/dac-adaptation-guide.md`、`docs/usb-output-settings-status.md`。

### Task 1: 提取可测试的远程音量决策

**Files:**
- Create: `test/android_remote_volume_test.dart`
- Modify: `lib/base/audio_handler.dart`

- [ ] **Step 1: 写失败测试**

覆盖：USB 硬件或数字音量真正生效时选择远程绝对音量；原始模式、非独占和 DSD 无硬件控制时选择本地音量；相对 raise/lower 每次改变 2%；绝对索引 0–100 映射到 0–1。

- [ ] **Step 2: 运行测试确认失败**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\android_remote_volume_test.dart
```

- [ ] **Step 3: 增加纯函数并测试**

纯函数放在 `audio_handler.dart` 现有音量逻辑旁，不新增 manager 或 bridge：

```dart
double adjustedRemoteVolume(double current, AndroidVolumeDirection direction) {
  final delta = switch (direction) {
    AndroidVolumeDirection.raise => 0.02,
    AndroidVolumeDirection.lower => -0.02,
    AndroidVolumeDirection.same => 0.0,
  };
  return (current + delta).clamp(0.0, 1.0).toDouble();
}

double absoluteRemoteVolume(int index) => index.clamp(0, 100) / 100;
```

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\android_remote_volume_test.dart
git add lib/base/audio_handler.dart test/android_remote_volume_test.dart
git commit -m "test(android): define remote USB volume behavior"
```

### Task 2: 接入 audio_service 远程音量媒体会话

**Files:**
- Modify: `lib/base/audio_handler.dart`

- [ ] **Step 1: 发布实际 PlaybackInfo**

增加 `_publishAndroidPlaybackInfo()`：当前独占状态的 `hardwareVolumeActive || digitalVolumeActive` 为真时发布：

```dart
androidPlaybackInfo.add(RemoteAndroidPlaybackInfo(
  volumeControlType: AndroidVolumeControlType.absolute,
  maxVolume: 100,
  volume: (volumeNotifier.value * 100).round(),
));
```

其它状态发布 `LocalAndroidPlaybackInfo()`。在独占状态变化、应用音量变化、DAC 主动事件和退出独占时调用。

- [ ] **Step 2: 覆盖相对与绝对回调**

```dart
@override
Future<void> androidAdjustRemoteVolume(AndroidVolumeDirection direction) async {
  _setUserVolume(adjustedRemoteVolume(volumeNotifier.value, direction));
}

@override
Future<void> androidSetRemoteVolume(int volumeIndex) async {
  _setUserVolume(absoluteRemoteVolume(volumeIndex));
}
```

`_setUserVolume` 统一更新 notifier、普通播放器/USB、媒体会话和持久化；只有实际远程控制生效时处理回调。

- [ ] **Step 3: 测试并提交**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\android_remote_volume_test.dart test\usb_audio_service_test.dart
F:\software\flutter_3.44.0\bin\flutter.bat analyze
git add lib/base/audio_handler.dart test/android_remote_volume_test.dart
git commit -m "feat(android): route background volume keys to USB playback"
```

### Task 3: 删除 Activity 前台重复拦截

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/MainActivity.kt`
- Modify: `lib/base/services/usb_audio_service.dart`
- Modify: `test/usb_audio_service_test.dart`

- [ ] **Step 1: 删除旧事件测试并补回归断言**

移除 `onUsbExclusiveVolumeKey` 累计 notifier 的测试，保留 DAC 自身 `onUsbHardwareVolumeChanged` 测试。全仓搜索应只剩设计或历史文档引用：

```powershell
rg -n "onUsbExclusiveVolumeKey|usbExclusiveVolumeKeyNotifier|dispatchKeyEvent" android lib test
```

- [ ] **Step 2: 删除旧拦截实现**

从 `MainActivity` 删除 `dispatchKeyEvent` 覆盖和不再需要的 `KeyEvent` import；从 Dart service 删除累计 notifier 与 native call 分支；从 `MyAudioHandler` 删除 `_lastVolumeKeyValue` 和旧 listener。MediaSession 成为手机物理键唯一入口。

- [ ] **Step 3: 测试并提交**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\android_remote_volume_test.dart test\usb_audio_service_test.dart
Set-Location android
.\gradlew.bat app:testDebugUnitTest
Set-Location ..
git add android/app/src/main/kotlin/com/afalphy/sylvakru/MainActivity.kt lib/base/services/usb_audio_service.dart lib/base/audio_handler.dart test/usb_audio_service_test.dart
git commit -m "refactor(android): remove foreground-only volume interception"
```

### Task 4: 重写通用 DAC 适配章节

**Files:**
- Modify: `docs/dac-adaptation-guide.md`
- Modify: `docs/usb-output-settings-status.md`

- [ ] **Step 1: 以能力为中心重排手册**

手册固定包含：描述符采集；标准 UAC/HID/Bulk 判断；写入与回读；主动事件捕获；范围、步进、左右声道与静音确认；协议实现；精确 quirk；测试矩阵；诊断附件。明确禁止仅按厂商 VID 泛化。

- [ ] **Step 2: 把 Macaron 降为完整示例**

保留已验证的 `ibassoDc03Pro` 命令、事件特征和日志，但放在“示例：Macaron/DC03 Pro”章节。通用章节不出现产品专有寄存器。

- [ ] **Step 3: 增加 AI 快速适配输入/输出模板**

模板要求输入 VID/PID、描述符、应用写入日志、DAC 按钮日志、当前 quirk 和失败状态；输出协议判断、仍缺证据、最小代码文件、测试样例和安全回退。开发者报告示例使用英文。

- [ ] **Step 4: 检查并提交**

```powershell
rg -n "VID|PID|Feature Unit|HID|Bulk|unsolicited|readback|fallback|Macaron" docs\dac-adaptation-guide.md
git diff --check -- docs/dac-adaptation-guide.md docs/usb-output-settings-status.md
git add docs/dac-adaptation-guide.md docs/usb-output-settings-status.md
git commit -m "docs(usb): generalize DAC vendor adaptation workflow"
```

### Task 5: 真机后台与双向同步验收

**Files:**
- Verify only: `build/app/outputs/flutter-apk/app-profile.apk`

- [ ] **Step 1: 完整自动验证**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.0\bin\flutter.bat test
F:\software\flutter_3.44.0\bin\flutter.bat analyze
F:\software\flutter_3.44.0\bin\flutter.bat build apk --profile --target-platform android-arm64
```

预期：全部测试通过、`No issues found`、arm64 profile APK 构建成功。

- [ ] **Step 2: 重新发现设备并安装**

```powershell
adb devices
adb install -r build\app\outputs\flutter-apk\app-profile.apk
adb shell monkey -p com.afalphy.sylvakru.profile 1
```

预期：目标设备状态为 `device`，安装和启动成功。若地址变化，以 `adb devices` 的实时结果为准。

- [ ] **Step 3: 手工矩阵**

依次验证应用前台、返回桌面、切到其它应用、熄屏、锁屏时的手机音量键；DAC 外置按键同步滑块和浮层；PCM、DoP、Native DSD；有/无 ReplayGain；拔插 DAC；切歌正负增益。强制停止应用后不要求接管按键。

- [ ] **Step 4: 检查提交范围并推送**

```powershell
git status --short
git log --oneline c7862ce..HEAD
git diff --stat fork/usb-exclusive-volume-overlay-performance...HEAD
git push fork usb-exclusive-volume-overlay-performance
```

预期：没有临时日志、APK、generated registrant 噪声或非 USB 视觉改动；推送成功。
