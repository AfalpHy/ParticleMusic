# USB 云端独占恢复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 WebDAV、Subsonic/Navidrome、Emby 的云端独占在后台或网络短暂停顿后保持 USB 独占并自动恢复，同时消除虚假缓冲目标和切歌状态错位。

**Architecture:** 保留现有 `Library` 作为唯一缓存协调点，各 client 统一返回完整下载结果并共享取消/残缺文件语义；USB 在途队列限制为真实可靠的 1000 ms，网络抗抖动继续由 `.part` 文件承担；独占请求与回调携带播放会话标识，PCM 与 DSD 切歌均保持等时传输连续。

**Tech Stack:** Flutter 3.44、Dart、Dio 5.9、Android Kotlin、JNI/C++ USBDEVFS、flutter_test、JUnit。

---

### Task 1: 统一所有云端下载完成、取消和残缺文件语义

**Files:**
- Modify: `test/cloud_download_client_test.dart`
- Modify: `lib/base/services/open_sonic_client.dart`
- Modify: `lib/base/services/subsonic_client.dart`
- Modify: `lib/base/services/webdav_client.dart`
- Modify: `lib/base/services/emby_client.dart`
- Modify: `lib/base/data/library.dart`

- [ ] **Step 1: 运行现有云端测试并记录 RED**

Run:

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test/cloud_download_client_test.dart
```

Expected: FAIL，当前 `OpenSubsonicClient.downloadSong` 返回 `void`、不接收 `CancelToken`，与测试和 `Library` 的完整下载契约不一致。

- [ ] **Step 2: 补齐三个协议的失败与取消回归测试**

在 `test/cloud_download_client_test.dart` 使用现有本地 `ServerSocket`，为 WebDAV、OpenSubsonic/Navidrome、Emby 各增加一次“声明 Content-Length 后中途断开”的用例，断言 client 返回 `false` 且 `.part` 仍存在；Navidrome 取消用例传入 `CancelToken`，断言返回 `false`。核心断言统一为：

```dart
final completed = await client.downloadSong(
  songId: 'song-id',
  savePath: partPath,
  cancelToken: cancelToken,
);

expect(completed, isFalse);
expect(File(partPath).existsSync(), isTrue);
```

WebDAV 使用 `download(remotePath:, localPath:, cancelToken:)`，Emby 使用 `downloadSong(itemId:, savePath:, cancelToken:)`，保持各 client 现有命名。

- [ ] **Step 3: 运行新增测试并确认失败原因正确**

Run:

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test/cloud_download_client_test.dart
```

Expected: FAIL，失败来自 OpenSubsonic 签名/错误删除行为或残缺下载被误判完成，而不是测试服务器语法错误。

- [ ] **Step 4: 用现有 client 方法统一最小契约**

把 `OpenSubsonicClient.downloadSong` 和 `SubsonicClient` override 改为：

```dart
Future<bool> downloadSong({
  required String songId,
  required String savePath,
  ProgressCallback? onProgress,
  CancelToken? cancelToken,
}) async {
  try {
    final uri = Uri.parse(baseUrl)
        .resolve('/rest/download.view')
        .replace(queryParameters: params({'id': songId}));
    await dio.download(
      uri.toString(),
      savePath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      deleteOnError: false,
      options: Options(receiveTimeout: Duration.zero),
    );
    return true;
  } on DioException catch (error) {
    if (!CancelToken.isCancel(error)) {
      logger.output('[$runtimeType] Download failed: ${error.message}');
    }
    return false;
  } catch (error) {
    logger.output('[$runtimeType] Download failed: $error');
    return false;
  }
}
```

`SubsonicClient` 转换服务器 ID 后原样转发 `cancelToken` 并返回 `Future<bool>`。确认 WebDAV、Emby 已使用 `deleteOnError: false`、`Duration.zero` 和 `CancelToken`；只补缺项，不新建公共 wrapper。

`Library._downloadOpenSubsonic` 直接返回 client 的布尔结果：

```dart
return client.downloadSong(
  songId: songId,
  savePath: savePath,
  cancelToken: cancelToken,
);
```

- [ ] **Step 5: 运行云端测试确认 GREEN**

Run:

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test/cloud_download_client_test.dart
```

Expected: PASS，慢速接收、残缺文件、取消和重试用例全部通过。

- [ ] **Step 6: 提交统一下载修复**

```powershell
git add test/cloud_download_client_test.dart lib/base/services/open_sonic_client.dart lib/base/services/subsonic_client.dart lib/base/services/webdav_client.dart lib/base/services/emby_client.dart lib/base/data/library.dart
git commit -m "fix(cloud): 统一流媒体独占下载恢复"
```

### Task 2: 让前后台缓冲设置与真实 USB 队列一致

**Files:**
- Modify: `test/usb_audio_preferences_test.dart`
- Modify: `lib/base/services/usb_audio_preferences.dart`
- Modify: `lib/base/services/usb_audio_service.dart`
- Modify: `lib/layer/audio_output_settings_layer.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/generated/app_localizations*.dart`

- [ ] **Step 1: 修改偏好测试表达真实上限**

把超过上限的输入断言改为 1000 ms，并增加序列化断言：

```dart
usbAudioPreferences.load({
  'usbForegroundBufferMs': 1400,
  'usbBackgroundBufferMs': 2400,
  'usbKeepAliveInBackground': true,
});

expect(usbAudioPreferences.foregroundBufferMsNotifier.value, 1000);
expect(usbAudioPreferences.backgroundBufferMsNotifier.value, 1000);
expect(preferredUsbExclusiveTargetBufferMs(background: true), 1000);
expect(usbAudioPreferences.toMap()['usbBackgroundBufferMs'], 1000);
```

- [ ] **Step 2: 运行偏好测试确认 RED**

Run:

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test/usb_audio_preferences_test.dart
```

Expected: FAIL，当前 `_validBufferMs` 和后台默认值仍允许 1500–5000 ms。

- [ ] **Step 3: 最小实现 50–1000 ms 约束**

在 `UsbAudioPreferences` 中把后台默认改为 1000，并让 `_validBufferMs` 对前后台统一 `clamp(50, 1000)`；`UsbAudioService.setExclusiveTargetBufferMs` 同样限制到 1000。设置页后台 slider 改为：

```dart
min: 50,
max: 1000,
divisions: 19,
```

中英文说明改为“USB 缓冲只吸收短时调度抖动，云端播放另外使用下载水位；上限 1000 ms”。用户可见文案只走 arb。

- [ ] **Step 4: 生成本地化并运行测试**

Run:

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.0\bin\flutter.bat test test/usb_audio_preferences_test.dart test/usb_audio_service_test.dart
```

Expected: PASS，生成文件只包含本次 arb 文案更新。

- [ ] **Step 5: 提交真实缓冲设置**

```powershell
git add test/usb_audio_preferences_test.dart lib/base/services/usb_audio_preferences.dart lib/base/services/usb_audio_service.dart lib/layer/audio_output_settings_layer.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated
git commit -m "fix(usb): 对齐真实传输缓冲上限"
```

### Task 3: 阻止旧歌曲声音与迟到状态覆盖新会话

**Files:**
- Modify: `test/usb_audio_service_test.dart`
- Modify: `lib/base/services/usb_audio_service.dart`
- Modify: `lib/base/audio_handler.dart`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbDsdTest.kt`

- [ ] **Step 1: 增加播放会话映射与旧回调测试**

为 `UsbExclusivePlaybackRequest` 增加必填 `playbackId`，测试 `toMap()` 包含该字段；为 `UsbExclusivePlaybackState` 测试 `fromMap()` 解析该字段。创建 service 后先发送当前 `playbackId` 的 active 回调，再发送旧 ID 回调，断言 notifier 保持当前状态：

```dart
expect(receivedArguments['playbackId'], 'load-7');
expect(usbExclusivePlaybackStateNotifier.value.playbackId, 'load-7');
```

- [ ] **Step 2: 运行 service 测试确认 RED**

Run:

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test/usb_audio_service_test.dart
```

Expected: FAIL，当前 request/state 没有 `playbackId`，平台回调也未过滤旧会话。

- [ ] **Step 3: 在 Dart 层传递和过滤会话标识**

`MyAudioHandler._tryOpenUsbExclusive` 用当前 `_loadGeneration` 生成 `playbackId`：

```dart
final playbackId = 'load-${generation ?? _loadGeneration}';
```

请求和状态模型携带该字段。`UsbAudioService.startExclusivePlayback` 记录当前 ID，平台 `onUsbExclusiveStateChanged/onUsbExclusivePosition/onUsbExclusiveError` 仅在 ID 相同或当前 ID 尚未建立时更新 notifier；停止当前会话后保留 ID，避免旧完成回调重新激活。

- [ ] **Step 4: 增加原生纯逻辑测试并确认 RED**

在 `UsbDsdTest.kt` 增加 PCM/DSD 停止策略测试，调用顶层纯函数：

```kotlin
assertEquals(true, shouldFlushOutputOnStop(null))
assertEquals(false, shouldFlushOutputOnStop("dop"))
assertEquals(false, shouldFlushOutputOnStop("native"))
```

Run:

```powershell
Set-Location android
.\gradlew.bat testDebugUnitTest --tests com.afalphy.sylvakru.UsbDsdTest
```

Expected: FAIL，函数尚不存在。

- [ ] **Step 5: 原生层回传会话 ID、PCM 清队列并提升线程优先级**

`UsbExclusiveAudioEngine.start` 读取请求 `playbackId`，创建初始 state 时写入；worker 捕获该 ID，所有 worker 状态通过带 ID 的更新入口发送，旧 ID 与当前 ID 不一致时不再覆盖 `currentState`。

增加纯函数：

```kotlin
internal fun shouldFlushOutputOnStop(dsdKind: String?): Boolean = false
```

`stop()` 不强制清空 PCM 或 DSD 的在途 URB，避免等时传输断流产生音爆；DoP/Native DSD 保持现有 idle filler。独占 worker lambda 开头设置：

```kotlin
Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
```

捕获 `SecurityException` 只记录英文诊断并继续普通优先级，不能让播放失败。

- [ ] **Step 6: 运行 Dart 与 Kotlin 测试确认 GREEN**

Run:

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test/usb_audio_service_test.dart
Set-Location android
.\gradlew.bat testDebugUnitTest --tests com.afalphy.sylvakru.UsbDsdTest --tests com.afalphy.sylvakru.UsbHardwareVolumeTest
```

Expected: PASS；现有硬件音量测试仍通过。

- [ ] **Step 7: 提交会话与切歌修复**

```powershell
git add test/usb_audio_service_test.dart lib/base/services/usb_audio_service.dart lib/base/audio_handler.dart android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt android/app/src/test/kotlin/com/afalphy/sylvakru/UsbDsdTest.kt
git commit -m "fix(usb): 隔离独占会话并清理旧曲缓冲"
```

### Task 4: 全量验证、arm64 profile 真机验收与推送

**Files:**
- Verify only; do not add generated plugin registrants or temporary logs.

- [ ] **Step 1: 运行相关测试**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test/cloud_download_client_test.dart test/usb_audio_preferences_test.dart test/usb_audio_service_test.dart test/audio_output_panel_test.dart test/audio_output_settings_layer_test.dart test/path_utils_test.dart
Set-Location android
.\gradlew.bat testDebugUnitTest
```

Expected: `All tests passed!`，Gradle `BUILD SUCCESSFUL`。

- [ ] **Step 2: 运行静态分析**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat analyze
```

Expected: `No issues found!`。

- [ ] **Step 3: 构建唯一允许的 arm64 profile APK**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat build apk --profile --target-platform android-arm64
```

Expected: `build/app/outputs/flutter-apk/app-profile.apk` 构建成功，不修改 Gradle ABI 配置。

- [ ] **Step 4: 真机验证**

先运行 `adb devices -l`，只对在线设备安装 profile APK。验证 Navidrome 未缓存 FLAC：起播、切后台打开高负载应用、网络短断恢复、连续快速切歌、暂停恢复。日志必须显示后台 target 为 1000 ms、worker 继续写入、恢复后 `.part` 继续增长、没有旧 playbackId 回调覆盖。

- [ ] **Step 5: 检查提交范围并推送**

```powershell
git status --short
git diff --check HEAD~3..HEAD
git log -4 --oneline
git push fork usb-exclusive-volume-overlay-performance
```

Expected: 只包含本计划的 USB/云端文件和用户原有已确认改动；generated plugin registrants、临时日志及非 USB 视觉文件未暂存。推送成功。
