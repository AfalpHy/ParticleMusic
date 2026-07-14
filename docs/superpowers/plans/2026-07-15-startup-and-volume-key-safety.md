# 启动恢复与手机音量键安全修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让应用首帧不再受上次歌曲元数据恢复阻塞，并把 USB 独占手机物理音量键恢复为仅前台自绘音量条控制。

**Architecture:** 保留现有 `Loader`、`MyAudioHandler` 和 USB 服务结构，只把播放状态解析与当前歌曲实际恢复拆成两个阶段：基础状态在启动前加载，歌曲在首帧后恢复。ReplayGain API/缓存补齐改为后台增强；Android MediaSession 始终发布本地音量，前台 `MainActivity` 通过相对按键事件驱动现有安全音量步进和自绘浮层。

**Tech Stack:** Flutter 3.44.5、Dart、audio_service、Android Kotlin、Flutter test、JUnit。

---

### Task 1: 拆分播放状态解析与歌曲恢复

**Files:**
- Modify: `lib/base/audio_handler.dart`
- Modify: `lib/main.dart`
- Test: `test/playback_restore_test.dart`

- [ ] **Step 1: 写失败测试**

新增纯状态边界测试，要求负索引或空队列不恢复，越界索引归零，有效索引保持不变：

```dart
test('恢复索引只在播放队列有效时返回', () {
  expect(restoredPlaybackIndex(-1, 3), isNull);
  expect(restoredPlaybackIndex(2, 0), isNull);
  expect(restoredPlaybackIndex(8, 3), 0);
  expect(restoredPlaybackIndex(2, 3), 2);
});
```

- [ ] **Step 2: 验证测试按预期失败**

运行：

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/playback_restore_test.dart
```

预期：因 `restoredPlaybackIndex` 尚不存在而编译失败。

- [ ] **Step 3: 实现最小状态拆分**

在 `audio_handler.dart` 中加入生产逻辑使用的索引规范化函数，并让 `loadPlayState()` 只恢复 JSON、音量和索引，不再直接 `await load()`：

```dart
int? restoredPlaybackIndex(int currentIndex, int queueLength) {
  if (currentIndex < 0 || queueLength <= 0) return null;
  return currentIndex < queueLength ? currentIndex : 0;
}

Future<void> restoreCurrentSong() async {
  final restored = restoredPlaybackIndex(currentIndex, playQueue.length);
  if (restored == null) return;
  currentIndex = restored;
  await load();
}
```

在 `main.dart` 的 `runApp()` 之后注册首帧回调，使用 `unawaited(audioHandler.restoreCurrentSong())`，捕获错误并写英文开发者日志。这样 `App start` 和首帧不等待歌词、封面、网络或 FFI 标签读取。

- [ ] **Step 4: 验证测试通过**

运行同一测试，预期全部通过。

- [ ] **Step 5: 提交启动恢复修改**

```powershell
git add lib/base/audio_handler.dart lib/main.dart test/playback_restore_test.dart
git commit -m "fix(audio): 首帧后恢复上次歌曲"
git push fork usb-exclusive-volume-overlay-performance
```

### Task 2: ReplayGain 补齐退出播放关键路径

**Files:**
- Modify: `lib/base/data/library.dart`
- Modify: `lib/base/audio_handler.dart`
- Test: `test/replay_gain_playback_supplement_test.dart`

- [ ] **Step 1: 写失败测试**

使用本机 `HttpServer` 接收 Navidrome 请求但不返回响应，证明播放补齐入口必须在 100 ms 内完成，而不是等待 API 的 1.5 秒超时：

```dart
test('播放 ReplayGain 补齐立即返回并在后台请求', () async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((_) {});
  navidromeClient = NavidromeClient(
    baseUrl: 'http://${server.address.host}:${server.port}',
    username: 'test',
    password: 'test',
  );
  final song = MyAudioMetadata(
    AudioMetadata(),
    id: 'slow-replay-gain',
    sourceType: .navidrome,
  );

  await library
      .supplementReplayGainForPlayback(song)
      .timeout(const Duration(milliseconds: 100));

  await server.close(force: true);
});
```

测试初始化临时 `appSupportDir` 与 `logger`，并在 `tearDown` 中恢复 `navidromeClient=null`、强制关闭服务器及删除临时目录，避免未完成请求污染其它测试。

- [ ] **Step 2: 验证测试按预期失败**

运行：

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/replay_gain_playback_supplement_test.dart
```

预期：当前实现等待 API 请求，100 ms 超时并失败。

- [ ] **Step 3: 实现后台补齐**

保留 `Future<void>` 兼容签名，但让公开入口只调度私有工作并立即完成，内部继续使用现有异常捕获：

```dart
Future<void> supplementReplayGainForPlayback(MyAudioMetadata song) async {
  unawaited(_supplementReplayGainForPlayback(song));
}
```

`audio_handler.dart` 不再把它放入 `Future.wait`；先触发后台补齐，再按现有逻辑加载歌词和封面。数据库已有 ReplayGain 立即使用，后台成功后继续通过 `replayGainMetadataChangedNotifier` 更新当前输出。

- [ ] **Step 4: 验证 ReplayGain 和启动恢复测试通过**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/replay_gain_playback_supplement_test.dart test/replay_gain_test.dart test/playback_restore_test.dart
```

预期：全部通过，无未处理异步异常。

- [ ] **Step 5: 提交 ReplayGain 修改**

```powershell
git add lib/base/data/library.dart lib/base/audio_handler.dart test/replay_gain_playback_supplement_test.dart
git commit -m "fix(replaygain): 后台补齐播放标签"
git push fork usb-exclusive-volume-overlay-performance
```

### Task 3: 恢复前台物理音量键与自绘浮层

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/MainActivity.kt`
- Modify: `lib/base/services/usb_audio_service.dart`
- Modify: `lib/base/audio_handler.dart`
- Modify: `test/android_remote_volume_test.dart`

- [ ] **Step 1: 写失败测试**

修改 Android 播放信息测试，要求 USB 独占硬件音量和数字音量状态都只发布 `LocalAndroidPlaybackInfo`；保留相对分贝步进测试，删除远程绝对索引映射断言：

```dart
test('USB 独占始终发布安卓本地音量信息', () {
  expect(
    androidPlaybackInfoFor(state(active: true, hardware: true, verified: true), 0.5),
    isA<audio_service.LocalAndroidPlaybackInfo>(),
  );
  expect(
    androidPlaybackInfoFor(state(active: true, digital: true), 0.5),
    isA<audio_service.LocalAndroidPlaybackInfo>(),
  );
});
```

- [ ] **Step 2: 验证测试按预期失败**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart
```

预期：当前实现返回 `RemoteAndroidPlaybackInfo`，断言失败。

- [ ] **Step 3: 实现本地播放信息与前台按键通道**

让 `androidPlaybackInfoFor` 始终返回 `LocalAndroidPlaybackInfo()`，删除远程绝对音量回调与无用映射函数。恢复 `MainActivity.dispatchKeyEvent`：仅当 `usbExclusiveAudioEngine.isVolumeControlEngaged()` 且 Activity 前台收到音量加减时吞掉事件，并通过 `onUsbExclusiveVolumeKey` 发送 `+1/-1`。

在 `usb_audio_service.dart` 恢复累计方向 notifier；在 `MyAudioHandler` 监听方向差值，调用现有 `_setUserVolumeImmediately(adjustedRemoteVolume(...))`，随后触发 `usbVolumeOverlayNotifier`。降低立即生效，提高继续受 2.5 dB 手机按键步长和现有输出渐升保护限制。

- [ ] **Step 4: 运行相关 Flutter 与 Android 测试**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart test/usb_volume_safety_test.dart
Set-Location android
.\gradlew.bat app:testDebugUnitTest
Set-Location ..
```

预期：Flutter 与 JUnit 测试全部通过。

- [ ] **Step 5: 提交物理按键修改**

```powershell
git add android/app/src/main/kotlin/com/afalphy/sylvakru/MainActivity.kt lib/base/services/usb_audio_service.dart lib/base/audio_handler.dart test/android_remote_volume_test.dart
git commit -m "fix(android): 恢复前台 USB 音量键浮层"
git push fork usb-exclusive-volume-overlay-performance
```

### Task 4: 完整验证与真机回归

**Files:**
- No production file changes expected.

- [ ] **Step 1: 格式化本次修改文件并检查差异**

```powershell
F:\software\flutter_3.44.5\bin\dart.bat format lib/main.dart lib/base/audio_handler.dart lib/base/data/library.dart lib/base/services/usb_audio_service.dart test/playback_restore_test.dart test/replay_gain_playback_supplement_test.dart test/android_remote_volume_test.dart
git diff --check
git diff --stat
git diff
```

- [ ] **Step 2: 执行 Flutter 全量验证**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.5\bin\flutter.bat test
F:\software\flutter_3.44.5\bin\flutter.bat analyze
```

预期：全部退出码为 0。

- [ ] **Step 3: 构建 arm64 Profile APK**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64
```

预期：生成 arm64 Profile APK，退出码为 0。

- [ ] **Step 4: 真机验证**

安装 Profile APK 后验证：异常歌曲作为上次歌曲时首帧正常出现；前台手机音量键只显示自绘条并控制 DAC；后台/熄屏按键不改变 DAC；DAC 旋钮仍双向同步；日志不存在 `FATAL EXCEPTION`、ANR 或未处理 Dart 异常。

- [ ] **Step 5: 检查最终仓库状态**

```powershell
git status
git log -4 --oneline
```

确认仅保留用户原有未提交修改，本任务提交均已推送至 `fork/usb-exclusive-volume-overlay-performance`。
