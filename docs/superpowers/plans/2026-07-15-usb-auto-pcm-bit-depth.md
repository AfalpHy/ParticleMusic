# USB PCM Auto Bit Depth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 PCM 自动位深按当前歌曲源位深选择兼容 USB 端点，并让设置页如实显示源、解码与 USB 槽位位深。

**Architecture:** 原生层在打开 USB 会话前预读 PCM 音轨位深，并把它作为自动端点排序依据；固定位深与 DSD 路径不变。Flutter 复用一个公开位深格式化函数，设置页只从独占状态的 `sourceBitDepth` 显示源文件位深。

**Tech Stack:** Android Kotlin、MediaExtractor、JUnit 4、Flutter/Dart、flutter_test。

---

### Task 1: 自动端点位深排序

**Files:**
- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`

- [ ] **Step 1: 写入失败测试**

新增测试，断言 16-bit 源在 `[16, 24, 32]` 中选择 16，20-bit 源选择最小更宽的 24，未知源保持旧的 24-bit 优先级，固定模式仍由现有 `bitDepth` 精确匹配分支处理。

```kotlin
@Test
fun selectsUsbSlotFromPcmSourceBitDepthInAutoMode() {
    assertEquals(16, preferredAutoPcmBitDepth(16, listOf(16, 24, 32)))
    assertEquals(24, preferredAutoPcmBitDepth(20, listOf(16, 24, 32)))
    assertEquals(24, preferredAutoPcmBitDepth(null, listOf(16, 24, 32)))
    assertNull(preferredAutoPcmBitDepth(32, listOf(16, 24)))
}
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `cd android && gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest.selectsUsbSlotFromPcmSourceBitDepthInAutoMode"`

Expected: FAIL，`preferredAutoPcmBitDepth` 尚不存在。

- [ ] **Step 3: 实现最小排序函数**

在 `UsbVolumeProtocol.kt` 增加纯函数：未知源沿用 `24、32、16`，已知源先精确匹配，再选最小更宽位深；不存在可容纳槽位时返回空值，让调用方使用兼容回退。

```kotlin
internal fun preferredAutoPcmBitDepth(sourceBitDepth: Int?, availableBitDepths: List<Int>): Int? {
    val available = availableBitDepths.filter { it > 0 }.distinct()
    if (sourceBitDepth == null) {
        return listOf(24, 32, 16).firstOrNull { it in available } ?: available.minOrNull()
    }
    return available.firstOrNull { it == sourceBitDepth }
        ?: available.filter { it > sourceBitDepth }.minOrNull()
}
```

- [ ] **Step 4: 预读歌曲位深并接入端点选择**

在 `UsbExclusiveAudioEngine.start` 中，只有 PCM 自动模式才用 `MediaExtractor` 读取音轨的 `bits-per-sample`。把该值传给 `findOutputTarget` 的自动候选分支，并纳入会话复用键；异常只记录英文日志并返回空值。

- [ ] **Step 5: 运行 Android 测试**

Run: `cd android && gradlew.bat app:testDebugUnitTest`

Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 6: 提交**

```bash
git add android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git commit -m "fix(usb): 按歌曲源位深选择 PCM 端点"
```

### Task 2: 修正位深展示语义

**Files:**
- Modify: `test/usb_audio_service_test.dart`
- Modify: `lib/base/widgets/audio_output_panel.dart`
- Modify: `lib/layer/audio_output_settings_layer.dart`

- [ ] **Step 1: 写入失败测试**

新增测试，直接验证共享格式化函数对 16-bit 返回 `16 bits`，对空源位深返回本地化“未知”。

```dart
test('源位深未知时不使用 USB 槽位冒充', () {
  final l10n = AppLocalizationsZh();
  expect(formatUsbBitDepth(16, l10n), '16 bits');
  expect(formatUsbBitDepth(null, l10n), l10n.unknown);
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart`

Expected: FAIL，`formatUsbBitDepth` 尚不存在。

- [ ] **Step 3: 实现共享格式化并修正设置页**

将 `audio_output_panel.dart` 的私有 `_formatBitDepth` 改为公开 `formatUsbBitDepth` 并复用。设置页“源文件”行在 PCM 独占激活时读取 `exclusive.sourceBitDepth`；未解析到时显示未知，不再调用输出端点位深标签。

- [ ] **Step 4: 运行 Flutter 测试与分析**

Run: `F:\software\flutter_3.44.5\bin\flutter.bat test`

Expected: 全部通过。

Run: `F:\software\flutter_3.44.5\bin\flutter.bat analyze`

Expected: `No issues found!`。

- [ ] **Step 5: 提交**

```bash
git add test/usb_audio_service_test.dart lib/base/widgets/audio_output_panel.dart lib/layer/audio_output_settings_layer.dart
git commit -m "fix(usb): 分开展示歌曲与端点位深"
```

### Task 3: 集成验证与推送

**Files:**
- Verify only

- [ ] **Step 1: 构建 arm64 Profile APK**

Run: `F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64`

Expected: 生成 `build/app/outputs/flutter-apk/app-profile.apk`。

- [ ] **Step 2: 安全真机验证**

安装 APK 后只验证应用启动与自动选择日志，不主动播放、不发送加音量按键。用户从低音量手动播放 16-bit 与 24-bit 歌曲后，日志应分别显示源位深、解码位深和选中端点位深。

- [ ] **Step 3: 检查并推送**

```bash
git diff --check
git status
git push fork usb-exclusive-volume-overlay-performance
```
