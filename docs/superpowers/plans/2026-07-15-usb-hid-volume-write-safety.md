# USB HID Volume Write Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 iBasso HID 健康状态的历史失败累计，让手机物理音量键在一次 USB 写入完成前不累计后续增大目标、单次固定调整 2%，并消除 PCM 兜底恢复硬件满幅前的裸露窗口。

**Architecture:** Kotlin 状态机在可信回读后完整恢复健康状态，DSD 安全门保持不变。Dart 只在手机物理音量键入口增加在途门，复用现有原生写入 Future 判断完成时机，不改滑条、DAC 旋钮或 ReplayGain；原生层修正 PCM 兜底交接顺序，不改变目标增益算法。

真机验证期间发现 PCM 兜底旧顺序会先恢复 DAC unity，再缓慢施加数字衰减。因此计划增加一个紧急安全任务：PCM 失去可信硬件音量时先立即施加当前有效数字增益，再恢复硬件 unity；硬件转数字禁止平滑，数字转已验证硬件仍可平滑。

**Tech Stack:** Flutter/Dart、Android Kotlin、JUnit 4、flutter_test。

---

### Task 1: 恢复可信回读后的 HID 健康状态

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

- [ ] **Step 1: 写入失败回归测试**

```kotlin
@Test
fun verifiedReadbackClearsPreviousReaderFailureBeforeNextFailure() {
    val recovered = IbassoReaderHealth()
        .afterFailure()
        .afterRestart()
        .afterVerifiedReadback()

    assertEquals(0, recovered.failureCount)
    assertFalse(recovered.restartRequested)
    assertFalse(recovered.writeOnly)
    assertTrue(recovered.readbackVerified)

    val nextFailure = recovered.afterFailure()
    assertEquals(1, nextFailure.failureCount)
    assertTrue(nextFailure.restartRequested)
    assertFalse(nextFailure.writeOnly)
}
```

- [ ] **Step 2: 运行测试并确认按预期失败**

Run: `cd android && gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest.verifiedReadbackClearsPreviousReaderFailureBeforeNextFailure"`

Expected: FAIL，`recovered.failureCount` 仍为 `1`，后续失败错误进入 `writeOnly=true`。

- [ ] **Step 3: 最小修复健康状态恢复**

```kotlin
fun afterVerifiedReadback(): IbassoReaderHealth = copy(
    failureCount = 0,
    pendingReadFailureCount = 0,
    restartRequested = false,
    writeOnly = false,
    readbackVerified = true,
)
```

- [ ] **Step 4: 运行目标测试与完整 Android 单元测试**

Run: `cd android && gradlew.bat app:testDebugUnitTest`

Expected: PASS。

- [ ] **Step 5: 提交并推送**

```bash
git add android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git commit -m "fix(usb): 恢复可信 HID 回读健康状态"
git push fork usb-exclusive-volume-overlay-performance
```

### Task 2: 手机音量键单次 2% 且在途不累计

**Files:**
- Modify: `lib/base/audio_handler.dart`
- Test: `test/android_remote_volume_test.dart`

- [ ] **Step 1: 把按键步长测试改为固定 2%**

```dart
expect(
  adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.raise),
  closeTo(0.52, 0.000001),
);
expect(
  adjustedRemoteVolume(0.5, audio_service.AndroidVolumeDirection.lower),
  closeTo(0.48, 0.000001),
);
expect(
  adjustedRemoteVolume(0.99, audio_service.AndroidVolumeDirection.raise),
  1,
);
expect(
  adjustedRemoteVolume(0.01, audio_service.AndroidVolumeDirection.lower),
  0,
);
```

- [ ] **Step 2: 运行测试并确认旧分贝步长导致失败**

Run: `F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart`

Expected: FAIL，旧实现返回按 2.5 dB 比例计算的值，而非固定加减 `0.02`。

- [ ] **Step 3: 实现固定 2% 与手机按键在途门**

```dart
const _phoneUsbVolumeStep = 0.02;

double adjustedRemoteVolume(double current, AndroidVolumeDirection direction) {
  final applied = current.clamp(0.0, 1.0).toDouble();
  if (identical(direction, AndroidVolumeDirection.raise)) {
    return (applied + _phoneUsbVolumeStep).clamp(0.0, 1.0).toDouble();
  }
  if (identical(direction, AndroidVolumeDirection.lower)) {
    return (applied - _phoneUsbVolumeStep).clamp(0.0, 1.0).toDouble();
  }
  return applied;
}
```

让 `_applyUsbExclusiveVolume()` 返回 `usbAudioService.setExclusiveVolume()` 的 Future，让 `_setUserVolumeImmediately()` 返回该 Future。`_handleUsbExclusiveVolumeKey()` 使用 `_phoneVolumeKeyWriteInProgress` 和 `try/finally` 等待本次写入；忙碌时直接返回，不修改 `volumeNotifier`，也不保留待处理目标。平台异常记录英文开发日志后解除忙碌状态。

- [ ] **Step 4: 运行相关测试、全量测试和静态分析**

Run: `F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart test/usb_volume_safety_test.dart`

Run: `F:\software\flutter_3.44.5\bin\flutter.bat test`

Run: `F:\software\flutter_3.44.5\bin\flutter.bat analyze`

Expected: 全部 PASS，analyze 无问题。

- [ ] **Step 5: 构建 arm64 Profile APK**

Run: `F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64`

Expected: 生成 `build/app/outputs/flutter-apk/app-profile.apk`。

- [ ] **Step 6: 提交并推送**

仅暂存 `lib/base/audio_handler.dart` 中本任务的代码块与 `test/android_remote_volume_test.dart`，保留该文件已有的用户格式修改。

```bash
git commit -m "fix(usb): 限制手机音量键在途累计"
git push fork usb-exclusive-volume-overlay-performance
```

- [ ] **Step 7: 安全真机检查**

安装 arm64 Profile APK，确认应用可启动且日志无新异常。不自动发送音量增大按键；由用户从低音量开始手动连续按键验证。

### Task 3: PCM 数字兜底先于硬件 unity 生效

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

- [ ] **Step 1: 写入失败回归测试**

测试 `shouldSmoothPcmVolumeHandoff()`：硬件转数字兜底必须返回 `false`，数字兜底转已验证硬件在启用平滑时返回 `true`。

- [ ] **Step 2: 运行测试并确认缺少安全判定函数**

Run: `cd android && gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest.attenuatesImmediatelyWhenPcmFallsBackFromHardwareVolume"`

Expected: FAIL，`shouldSmoothPcmVolumeHandoff` 尚不存在。

- [ ] **Step 3: 实现立即数字衰减**

在 iBasso 读线程进入只写状态和硬件音量写入失败恢复 unity 之前，以 `smooth=false` 立即施加 `effectiveVolumeGainQ16(requestedVolumeGainQ16, requestedReplayGainMilliDb)`。最终交接只在 `!wasHardwareActive && hardwareVolumeActive` 时允许平滑。

- [ ] **Step 4: 运行完整 Android 单元测试**

Run: `cd android && gradlew.bat app:testDebugUnitTest`

Expected: PASS。

- [ ] **Step 5: 提交并推送**

```bash
git commit -m "fix(usb): 在恢复硬件满幅前启用 PCM 衰减"
git push fork usb-exclusive-volume-overlay-performance
```
